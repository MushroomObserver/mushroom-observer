# frozen_string_literal: true

require("test_helper")

# Guard tests that pin "what's a full-page action view" structurally,
# so a future PR can't silently misclassify a turbo_stream fragment
# or a nested sub-view as a `Views::FullPageBase` subclass — which
# would wrap it in the application layout and double-render the
# chrome at the wrong level.
#
# Two rules enforced:
#
# 1. **Controllers** — any `Views::Controllers::*` class rendered
#    from a `format.turbo_stream { ... }` line OR with a
#    `layout: false` kwarg on its own `render(...)` call MUST NOT
#    inherit from `Views::FullPageBase`. Those renders return
#    turbo-stream fragments or modal HTML that must not carry
#    full-page chrome.
#
# 2. **Phlex views** — any `Views::Controllers::*` class instantiated
#    inside another Phlex view's `render(...)` call MUST NOT inherit
#    from `Views::FullPageBase`. A FullPageBase subclass is by
#    definition the top-level page; rendering one inside another
#    page would wrap the inner content in the layout a second time.
class FullPageBaseInheritanceTest < ActiveSupport::TestCase
  # Matches a fully-qualified `Views::Controllers::Foo::Bar` class
  # name (any depth). Shared by Rule 1 (inline turbo_stream) and
  # Rule 2 (Phlex-render scan) — extracted to a constant so the
  # `format.turbo_stream` regex stays under the line-length limit.
  CONTROLLER_CLASS_RE =
    /Views::Controllers::(?:[A-Z][A-Za-z0-9_]*::)*[A-Z][A-Za-z0-9_]*/

  # Eager-load so every `Views::Controllers::*` autoloadable constant
  # is defined and the `< Views::FullPageBase` check reflects the
  # live class hierarchy, not just the file text.
  setup do
    Rails.application.eager_load!
  end

  # ---- Rule 1: controllers --------------------------------------------

  def test_layout_false_renders_do_not_use_full_page_base
    offenders = []
    each_controller_render_call do |path, line_no, class_name, body|
      next unless body.match?(/layout:\s*false/)

      klass = lookup_class(class_name)
      next unless klass && klass < Views::FullPageBase

      offenders << { file: path, line: line_no, klass: klass.name }
    end

    assert_empty(offenders.uniq, format_offenders(<<~MSG, offenders))
      The following `Views::Controllers::*` classes are rendered with
      `layout: false` but inherit from `Views::FullPageBase`. The
      controller is asking Rails to skip the layout (typical for
      modal / turbo_stream responses), but the FullPageBase wrap
      will fire anyway, producing a full-page document inside a
      fragment response. Change the class to inherit from
      `Views::Base` instead.
    MSG
  end

  def test_inline_turbo_stream_renders_do_not_use_full_page_base
    offenders = []
    controller_files.each do |path|
      File.readlines(path).each_with_index do |line, i|
        # Only catch the inline form: `format.turbo_stream { render(Foo.new) }`.
        # The `[^{}]*` between `{` and `render(` keeps the regex
        # scoped to the inline block. Multi-line
        # `format.turbo_stream do ... end` blocks aren't parsed
        # here — they're rare in MO and not worth a custom block
        # scanner; Rule 2 catches nested-render misclassification.
        prefix = /format\.turbo_stream\s*\{[^{}]*render\([^()]*/
        match = line.match(/#{prefix}(#{CONTROLLER_CLASS_RE})\.new/o)
        next unless match

        klass = lookup_class(match[1])
        next unless klass && klass < Views::FullPageBase

        offenders << { file: path, line: i + 1, klass: klass.name }
      end
    end

    assert_empty(offenders, format_offenders(<<~MSG, offenders))
      The following `Views::Controllers::*` classes are rendered
      from a `format.turbo_stream { ... }` line but inherit from
      `Views::FullPageBase`. The wrap will fire on the turbo_stream
      render and emit the full application layout inside the
      stream, breaking the page. Change the class to inherit from
      `Views::Base` instead.
    MSG
  end

  # ---- Rule 2: Phlex views --------------------------------------------

  def test_phlex_views_do_not_render_other_full_page_views
    offenders = []
    phlex_view_files.each do |path|
      # Skip the file's OWN class — `class Foo < Views::FullPageBase`
      # may reference itself in the constructor / factory, that's
      # not a "render of another full-page" violation.
      own_class = own_class_for(path)
      src = File.read(path)
      src.scan(rendered_class_pattern) do |match|
        class_name = match[0]
        next if own_class && class_name == own_class

        klass = lookup_class(class_name)
        next unless klass && klass < Views::FullPageBase

        offenders << { caller_file: path, rendered: klass.name }
      end
    end

    assert_empty(offenders.uniq, format_render_offenders(<<~MSG, offenders))
      The following Phlex views render a `Views::FullPageBase`
      subclass via `render(Some::Class.new(...))`. A FullPageBase
      subclass is the top-level page wrapper; rendering one inside
      another Phlex view nests the application layout inside
      itself. Move the inner class to `Views::Base` (it's a
      sub-component, not a top-level page).
    MSG
  end

  private

  # Iterates every `render(Views::Controllers::Foo.new(...))` call
  # in every controller file. For each, yields the controller path,
  # the line of the `render(`, the class name, and the full source
  # text of the render call (from `render(` to the matching `)`).
  def each_controller_render_call
    controller_files.each do |path|
      src = File.read(path)
      src.to_enum(:scan, render_call_start_pattern).each do
        match = ::Regexp.last_match
        offset = match.begin(0)
        class_name = match[1]
        body = render_call_body(src, offset)
        line_no = src[0...offset].count("\n") + 1
        yield(path, line_no, class_name, body)
      end
    end
  end

  # Matches the opening of a `render(Views::Controllers::Foo.new`
  # call. The full call extent is extracted by `render_call_body`
  # by walking parens.
  def render_call_start_pattern
    /render\(\s*(#{CONTROLLER_CLASS_RE})\.new/o
  end

  # Walks parens from the `render(` start to find the matching `)`,
  # returning the full source text of the render call. Used to scope
  # the `layout: false` check to the SAME render call (avoids
  # picking up `layout: false` from an unrelated nearby call).
  def render_call_body(src, start_offset)
    open_paren = src.index("(", start_offset)
    return "" unless open_paren

    depth = 0
    i = open_paren
    while i < src.length
      c = src[i]
      depth += 1 if c == "("
      depth -= 1 if c == ")"
      return src[start_offset..i] if depth.zero?

      i += 1
    end
    src[start_offset..]
  end

  # Captures `Views::Controllers::Foo::Bar` instantiations inside
  # `render(...)`. Used by Rule 2 (Phlex-view scanning).
  def rendered_class_pattern
    /render\(\s*(#{CONTROLLER_CLASS_RE})\.new/o
  end

  # For a Phlex view file under `app/views/controllers/`, returns
  # the qualified class name that the file declares. Used to skip
  # self-references in Rule 2's render scan.
  def own_class_for(path)
    rel = path.to_s.sub(%r{.*?/app/views/controllers/}, "").delete_suffix(".rb")
    parts = rel.split("/").map(&:camelize)
    "Views::Controllers::#{parts.join("::")}"
  end

  def lookup_class(name)
    name.constantize
  rescue ::NameError
    nil
  end

  def controller_files
    Rails.root.glob("app/controllers/**/*.rb")
  end

  def phlex_view_files
    Rails.root.glob("app/views/**/*.rb")
  end

  def format_offenders(header, offenders)
    return "" if offenders.empty?

    lines = offenders.uniq.map do |o|
      "  - #{o[:klass]} (#{o[:file]}:#{o[:line]})"
    end
    "#{header}\n#{lines.join("\n")}"
  end

  def format_render_offenders(header, offenders)
    return "" if offenders.empty?

    lines = offenders.uniq.map do |o|
      "  - #{o[:rendered]} rendered from #{o[:caller_file]}"
    end
    "#{header}\n#{lines.join("\n")}"
  end
end

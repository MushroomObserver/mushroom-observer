# frozen_string_literal: true

require("test_helper")

# Guards against the `helpers.foo(...)` antipattern inside Phlex
# views / components.
#
# Per `.claude/rules/phlex_conversions.md`:
#
# > Never call `helpers.foo` from inside a Phlex view. It's not a
# > substitute for registering — it's worse (silent runtime
# > dispatch into ActionView, brittle across Phlex versions). If
# > `foo` needs to be reachable from the view, either inline it or
# > go through the proper registration channels.
#
# Both `helpers.foo` and `ApplicationController.helpers.foo` (or any
# `<Class>.helpers.foo`) hit the same ActionView dispatch, so both
# are flagged. Comments are ignored.
class NoHelpersInPhlexViewsTest < ActiveSupport::TestCase
  PHLEX_GLOBS = %w[
    app/components/**/*.rb
    app/views/**/*.rb
  ].freeze

  # `\bhelpers\.` — `helpers` as a whole word followed by `.`.
  # Matches `helpers.foo`, `ApplicationController.helpers.foo`,
  # `MyClass.helpers.foo`, etc. Does NOT match `module_helpers.foo`
  # because the `_` before `helpers` is a word character and breaks
  # the `\b` boundary.
  #
  # `\w+[!?=]?` after the dot — Ruby method names can end in
  # `!` / `?` / `=`, so e.g. `helpers.content_for?` is also flagged.
  HELPERS_PATTERN = /\bhelpers\.\w+[!?=]?/

  def test_no_helpers_in_phlex_views
    offenders = scan_for_helpers
    assert_empty(offenders, build_failure_message(offenders))
  end

  # --- Unit tests for the scanner itself ------------------------

  def test_scanner_flags_helpers_calls
    assert_bad("helpers.link_to('foo', '#')")
    assert_bad("  helpers.url_for(action: :show)")
    assert_bad("  x = helpers.t('foo.bar')")
    assert_bad("plain(helpers.content_for(:left))")
    # Methods ending in `?` / `!` / `=`.
    assert_bad("helpers.content_for?(:left)")
    assert_bad("helpers.flash_clear!")
    # Class-level helpers proxy — same ActionView dispatch.
    assert_bad("ApplicationController.helpers.link_to(name, path)")
    assert_bad("MyController.helpers.tag.a(name)")
  end

  def test_scanner_ignores_identifiers_ending_in_helpers
    # `module_helpers.foo` is one word followed by `.foo`; the `_`
    # breaks the `\bhelpers\b` boundary.
    assert_clean("module_helpers.foo")
    assert_clean("my_helpers.bar")
  end

  def test_scanner_ignores_helpers_in_comments
    assert_clean("# `helpers.foo` is forbidden; inline instead")
    assert_clean("  # see helpers.rb deletes after both inlinings")
    assert_clean("# explains helpers.foo behavior")
  end

  private

  def assert_bad(snippet)
    offenders = scan_file("test.rb", [snippet])
    assert_not_empty(offenders, "expected scanner to flag:\n#{snippet}")
  end

  def assert_clean(snippet)
    offenders = scan_file("test.rb", [snippet])
    assert_empty(offenders, "expected scanner to allow:\n#{snippet}")
  end

  def scan_for_helpers
    files = PHLEX_GLOBS.flat_map { |g| Rails.root.glob(g) }
    files.flat_map do |path|
      rel = Pathname.new(path).relative_path_from(Rails.root).to_s
      lines = File.readlines(path)
      scan_file(rel, lines)
    end
  end

  def scan_file(rel, lines)
    offenders = []
    lines.each_with_index do |raw, idx|
      next if comment_line?(raw)

      stripped = strip_inline_comment(raw)
      next unless stripped.match?(HELPERS_PATTERN)

      offenders << { path: rel, line: idx + 1, snippet: raw.strip }
    end
    offenders
  end

  def comment_line?(line)
    line.lstrip.start_with?("#")
  end

  def strip_inline_comment(line)
    in_str = nil
    out = +""
    line.each_char do |c|
      if in_str
        in_str = nil if c == in_str
        out << c
      elsif ['"', "'"].include?(c)
        in_str = c
        out << c
      elsif c == "#"
        break
      else
        out << c
      end
    end
    out
  end

  def build_failure_message(offenders)
    return "" if offenders.empty?

    rendered = offenders.map do |o|
      "  #{o[:path]}:#{o[:line]}: #{o[:snippet]}"
    end
    <<~MSG
      `helpers.foo(...)` calls found in Phlex view/component files.

      Both `helpers.foo` and `<Class>.helpers.foo` (e.g.
      `ApplicationController.helpers.foo`) dispatch silently into
      ActionView and are brittle across Phlex versions. Inline the
      logic, or register the helper via
      `register_value_helper` / `register_output_helper` on a
      shared base.

      When you need a Phlex tag to return a string for
      interpolation (e.g. into a `.t(name: …)` translation), use
      `capture { a(href: …) { … } }` — capture returns an
      `ActiveSupport::SafeBuffer`.

      Offenders:
      #{rendered.join("\n")}
    MSG
  end
end

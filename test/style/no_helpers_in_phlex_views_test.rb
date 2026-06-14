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
# This test scans every `app/components/**/*.rb` and
# `app/views/**/*.rb` file and fails if any line has a bare
# `helpers.<method>` call (i.e. `helpers.` preceded by a non-word
# character or start-of-line, NOT preceded by a `.` — which would
# make it a longer chain like `ApplicationController.helpers.foo`).
#
# What we leave alone:
#   - Comments. Discussion / removal-notes that mention "helpers."
#     in prose shouldn't trigger this.
#   - ERB files (`*.erb`). Same as the no-queries scanner.
#   - `register_value_helper` / `register_output_helper`. They use
#     the `helper` (singular) keyword for the macro, but might
#     mention `helpers` in surrounding doc — the receiver pattern
#     `.helpers.foo` is a different thing.
#   - `ApplicationController.helpers.foo`. The class-level
#     `helpers` proxy is technically distinct from the
#     instance-level antipattern, and the regex (no preceding `.`)
#     wouldn't flag it anyway. Phlex's `capture { a(...) { ... } }`
#     should be reached for first when a Phlex tag needs to return
#     a string for interpolation — see
#     `Names::Versions::Show#name_link_for_source` for the worked
#     example.
class NoHelpersInPhlexViewsTest < ActiveSupport::TestCase
  PHLEX_GLOBS = %w[
    app/components/**/*.rb
    app/views/**/*.rb
  ].freeze

  # `(?<![\w.])` — no word character and no `.` immediately before
  # `helpers` (so `ApplicationController.helpers.foo` and
  # `nested_helpers.foo` don't match, but `helpers.foo` at the
  # start of an expression does).
  #
  # `\w+[!?=]?` after the dot — Ruby method names can end in
  # `!` / `?` / `=`, so e.g. `helpers.content_for?` is also flagged.
  HELPERS_PATTERN = /(?<![\w.])helpers\.\w+[!?=]?/

  def test_no_helpers_in_phlex_views
    offenders = scan_for_helpers
    assert_empty(offenders, build_failure_message(offenders))
  end

  # --- Unit tests for the scanner itself ------------------------

  def test_scanner_flags_bare_helpers_call
    assert_bad("helpers.link_to('foo', '#')")
    assert_bad("  helpers.url_for(action: :show)")
    assert_bad("  x = helpers.t('foo.bar')")
    assert_bad("plain(helpers.content_for(:left))")
    # Methods ending in `?` / `!` / `=`.
    assert_bad("helpers.content_for?(:left)")
    assert_bad("helpers.flash_clear!")
  end

  def test_scanner_allows_application_controller_proxy
    assert_clean("ApplicationController.helpers.link_to(name, path)")
    assert_clean("MyController.helpers.tag.a(name)")
  end

  def test_scanner_allows_chained_helpers_on_unrelated_receiver
    # `Module#helpers` on something other than `self`, chained from
    # an identifier ending in alphanumeric, isn't the antipattern.
    assert_clean("File.helpers.foo") # pretend module method
    assert_clean("MyClass.helpers.bar")
  end

  def test_scanner_ignores_word_helpers_in_comments
    assert_clean("# `helpers.foo` is forbidden; inline instead")
    assert_clean("  # see helpers.rb deletes after both inlinings")
  end

  def test_scanner_ignores_helpers_in_comments
    # NOTE: the scanner only strips comments, not strings. Strings
    # that literally include `helpers.foo` text are extremely rare
    # in views/components and would be flagged — fix the string if
    # it ever shows up rather than complicating the scanner.
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

      Per `.claude/rules/phlex_conversions.md`: never call
      `helpers.foo` from inside a Phlex view. It's a silent runtime
      dispatch into ActionView, brittle across Phlex versions. If
      `foo` needs to be reachable from the view, either inline it
      or go through the proper registration channels
      (`register_value_helper` / `register_output_helper` on a
      shared base — but ask first; see the rule for when
      registration is OK vs when to inline).

      When you need a Phlex tag to return an HTML-safe string
      (instead of writing to the output buffer) — for example to
      interpolate a link into a `.t(name: …)` translation —
      reach for `capture { a(href: …) { … } }` first.
      `ApplicationController.helpers.foo` is allowed by the regex
      (no preceding `.`), but the `capture` path is preferred.

      Offenders:
      #{rendered.join("\n")}
    MSG
  end
end

# frozen_string_literal: true

require("test_helper")

# Enforces the "concrete prop types over `_Any`" rule from
# `.claude/rules/phlex_conversions.md` ("ALWAYS use concrete prop
# types — never `_Any` when the type is known").
#
# Scans every `app/components/**/*.rb` and `app/views/**/*.rb` file
# for `prop … _Any …` declarations and fails on uses outside the
# one sanctioned context: `_Hash(Key, _Any)` (and its nilable
# cousin `_Hash(Key, _Any?)`). The Hash carve-out covers
# HTML-attribute pass-throughs (`attributes`, `data`, `args`,
# `extra_data`, …) where the value type genuinely is arbitrary.
#
# Multi-line aware: a `prop` declaration whose type expression
# wraps across lines is collected up to its paren-balanced end,
# and each `_Any` token's innermost enclosing `_Foo(...)` call is
# checked — only `_Hash(...)` is exempt. A future contributor who
# tucks `_Any` deep inside a multi-line `_Union(...)` won't slip
# past this guard.
#
# Why we draw the line at `_Any`:
#
#   - Concrete types (`prop :user, ::User`) raise
#     `Literal::TypeError` at construction time when a caller
#     passes the wrong shape; `_Any` accepts anything and the
#     failure surfaces later as a cryptic `NoMethodError` deep
#     inside `view_template`.
#   - Most "any" props really aren't — they're an
#     `ActiveRecord::Relation`, an `Array` of a known model, or a
#     duck-typed shape reachable via `_Interface(:method_name)`.
#   - Even when the value really is polymorphic (a Comment
#     target, an InlineModLinks target, …), `_Interface(:type_tag,
#     :id)` pins the contract more tightly than `_Any` and still
#     accepts the full polymorphic set.
class NoAnyPhlexPropsTest < ActiveSupport::TestCase
  PHLEX_GLOBS = %w[
    app/components/**/*.rb
    app/views/**/*.rb
  ].freeze

  # A `prop :…, …` declaration. The type expression follows the
  # comma; collected up to its paren-balanced end.
  PROP_START_RE = /^\s*prop\s+:\w+\s*,/

  # `_Foo(` opens a named-type call; we track the name so we can
  # check whether a `_Any` token inside it is the value slot of a
  # `_Hash`.
  NAMED_OPEN_RE = /\A_([A-Z]\w*)\s*\(/

  # `_Any` or `_Any?` — the offender pattern.
  ANY_TOKEN_RE = /\A_Any\??\b/

  def test_no_bare_any_phlex_props
    offenders = scan_for_bare_any_props
    assert_empty(offenders, build_failure_message(offenders))
  end

  # --- Unit tests for the scanner itself ------------------------

  def test_scanner_flags_bare_any
    assert_bad("prop :foo, _Any")
    assert_bad("prop :foo, _Nilable(_Any), default: nil")
    assert_bad("prop :foo, _Array(_Any)")
  end

  def test_scanner_allows_hash_value_any
    assert_clean("prop :foo, _Hash(Symbol, _Any), default: -> { {} }")
    assert_clean("prop :foo, _Hash(_Union(Symbol, String), _Any?)")
  end

  def test_scanner_flags_any_outside_hash_in_multiline_prop
    # Multi-line: `_Any` inside `_Union` (not `_Hash`) — must
    # flag even though the type expression wraps across lines.
    assert_bad(<<~RUBY)
      prop :foo, _Union(
        _Hash(Symbol, _Any),
        _Nilable(_Any)
      )
    RUBY
  end

  def test_scanner_allows_nested_hash_any_in_multiline_prop
    # Multi-line: every `_Any` here is the value slot of a
    # `_Hash(...)`. Should pass.
    assert_clean(<<~RUBY)
      prop :exif_data,
           _Hash(Integer, _Hash(Symbol, _Any?)),
           default: -> { {} }
    RUBY
  end

  def test_scanner_allows_bare_any_inside_hash_across_lines
    # The `_Any` is the value of `_Hash`, but on a different
    # physical line from the `_Hash(` token. The old line-based
    # scanner would have OK'd this only via the line-contains-
    # `_Hash(` heuristic; the new walker validates via the
    # paren stack.
    assert_clean(<<~RUBY)
      prop :attrs,
           _Hash(
             _Union(Symbol, String),
             _Any?
           )
    RUBY
  end

  def test_scanner_flags_any_in_tuple_inside_array_across_lines
    # `_Any?` here is inside `_Tuple` inside `_Array` —
    # neither has `_Hash` as the immediate enclosing call, so
    # the offender lives deep inside a multi-line declaration.
    assert_bad(<<~RUBY)
      prop :options, _Array(
        _Union(
          _Nilable(String),
          _Tuple(String, _Any?)
        )
      )
    RUBY
  end

  private

  def assert_bad(snippet)
    lines = snippet.lines
    offenders = scan_file("test.rb", lines)
    assert_not_empty(offenders,
                     "expected scanner to flag:\n#{snippet}")
  end

  def assert_clean(snippet)
    lines = snippet.lines
    offenders = scan_file("test.rb", lines)
    assert_empty(offenders, "expected scanner to allow:\n#{snippet}")
  end

  # Returns `[{ path:, line:, snippet: }, …]` for every `_Any`
  # outside a `_Hash(…)` value slot.
  def scan_for_bare_any_props
    files = PHLEX_GLOBS.flat_map { |g| Rails.root.glob(g) }
    files.flat_map do |path|
      rel = Pathname.new(path).relative_path_from(Rails.root).to_s
      lines = File.readlines(path)
      scan_file(rel, lines)
    end
  end

  def scan_file(rel, lines)
    offenders = []
    i = 0
    while i < lines.length
      unless lines[i].match?(PROP_START_RE)
        i += 1
        next
      end
      statement, lines_consumed, start_line = collect_statement(lines, i)
      bad_count = bad_any_count(statement)
      if bad_count.positive?
        offenders << {
          path: rel,
          line: start_line,
          snippet: statement.strip.lines.first.strip
        }
      end
      i += lines_consumed
    end
    offenders
  end

  # Walks forward from `start_idx` collecting lines until the
  # `prop` statement's parens are balanced. Returns the joined
  # text, the number of lines consumed, and the 1-based starting
  # line number.
  def collect_statement(lines, start_idx)
    text = +""
    j = start_idx
    depth = 0
    loop do
      line = lines[j]
      text << line
      depth += line.count("(") - line.count(")")
      j += 1
      break if depth <= 0 || j >= lines.length
    end
    [text, j - start_idx, start_idx + 1]
  end

  # Walks the statement's type expression with a paren stack;
  # each opening paren remembers the `_Foo` name if any. A
  # `_Any` token is bad unless its innermost named ancestor is
  # `_Hash`.
  def bad_any_count(statement)
    stack = [] # entries are `_Foo` strings or "" for bare "("
    i = 0
    bad = 0
    while i < statement.length
      rest = statement[i..]
      if (m = NAMED_OPEN_RE.match(rest))
        stack.push("_#{m[1]}")
        i += m.end(0)
      elsif statement[i] == "("
        stack.push("")
        i += 1
      elsif statement[i] == ")"
        stack.pop
        i += 1
      elsif (m = ANY_TOKEN_RE.match(rest))
        bad += 1 unless inside_hash?(stack)
        i += m.end(0)
      else
        i += 1
      end
    end
    bad
  end

  def inside_hash?(stack)
    stack.reverse_each do |name|
      next if name.empty?

      return name == "_Hash"
    end
    false
  end

  def build_failure_message(offenders)
    return "" if offenders.empty?

    rendered = offenders.map do |o|
      "  #{o[:path]}:#{o[:line]}: #{o[:snippet]}"
    end
    <<~MSG
      Bare `_Any` prop declarations found in Phlex view/component files.

      Concrete prop types catch caller mistakes at construction time
      (`Literal::TypeError`) rather than failing later inside
      `view_template` with a cryptic `NoMethodError`. Replace `_Any`
      with the concrete class (`::User`, `::Name`, ...), a generic
      (`_Array(::Foo)`, `_Union(Array, ActiveRecord::Relation)`),
      or a duck-typed `_Interface(:method_name)`.

      The one sanctioned shape is `_Hash(Key, _Any)` (and its
      nilable cousin) — for HTML-attribute pass-throughs where the
      value type genuinely is arbitrary.

      Offenders:
      #{rendered.join("\n")}
    MSG
  end
end

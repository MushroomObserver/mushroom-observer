# frozen_string_literal: true

require("test_helper")

# Enforces the "concrete prop types over `_Any`" rule from
# `.claude/rules/phlex_conversions.md` ("ALWAYS use concrete prop
# types — never `_Any` when the type is known").
#
# Scans every `app/components/**/*.rb` and `app/views/**/*.rb` file
# for `prop … _Any …` lines and fails on uses outside the one
# sanctioned context: `_Hash(Key, _Any)` (and its nilable cousin
# `_Hash(Key, _Any?)`). The Hash carve-out covers HTML-attribute
# pass-throughs (`attributes`, `data`, `args`, `extra_data`, …)
# where the value type genuinely is arbitrary.
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

  # Match `prop :name, …` lines that contain `_Any` (with or
  # without `?`). Captures the file and line for the failure
  # message; classification happens below.
  PROP_RE = /^\s*prop\s+:\w+\s*,/

  # A `_Any` token is sanctioned when the line also contains
  # `_Hash(...)` somewhere before it — i.e. the `_Any` is the
  # value-type slot of a Hash declaration. The simple "line
  # contains `_Hash(`" check is sufficient because Hash and
  # non-Hash `_Any` props don't co-occur on the same prop line in
  # MO's codebase.
  HASH_GUARD_RE = /_Hash\(/

  def test_no_bare_any_phlex_props
    offenders = scan_for_bare_any_props
    assert_empty(offenders, build_failure_message(offenders))
  end

  private

  # Returns `{ "relative/path.rb" => [[line_no, snippet], …] }`
  # for every file with a non-Hash `_Any` prop declaration.
  def scan_for_bare_any_props
    files = PHLEX_GLOBS.flat_map { |g| Rails.root.glob(g) }
    files.each_with_object({}) do |path, acc|
      rel = Pathname.new(path).relative_path_from(Rails.root).to_s
      hits = File.foreach(path).with_index(1).filter_map do |line, n|
        next unless prop_line_with_any?(line)
        next if hash_value_any?(line)

        [n, line.rstrip]
      end
      acc[rel] = hits if hits.any?
    end
  end

  def prop_line_with_any?(line)
    line.match?(PROP_RE) && line.include?("_Any")
  end

  def hash_value_any?(line)
    line.match?(HASH_GUARD_RE)
  end

  def build_failure_message(offenders)
    return "" if offenders.empty?

    rendered = offenders.flat_map do |path, lines|
      lines.map { |(n, snippet)| "  #{path}:#{n}: #{snippet.strip}" }
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

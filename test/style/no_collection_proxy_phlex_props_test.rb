# frozen_string_literal: true

require("test_helper")

# Enforces "callers `.to_a` their AR collections at the render site"
# for Phlex views/components. Scans every `app/components/**/*.rb`
# and `app/views/**/*.rb` file for `prop` declarations whose type
# expression names `ActiveRecord::Associations::CollectionProxy` and
# fails when any are found.
#
# The shape this guard exists to kill is
#
#   prop :versions,
#        _Union(Array, ActiveRecord::Associations::CollectionProxy),
#        default: -> { [] }
#
# which accepts either a real Array or a Rails AR collection. Two
# things are wrong with it: the prop's element type isn't validated
# at all (just the top-level container), and the type union papers
# over a caller that should have called `.to_a` on its collection at
# the render site.
#
# Replace with `_Array(_Interface(:method_the_view_uses))` (or a
# concrete class, when the view only renders one model's versions),
# and update callers to pass `obj.collection.to_a`.
class NoCollectionProxyPhlexPropsTest < ActiveSupport::TestCase
  PHLEX_GLOBS = %w[
    app/components/**/*.rb
    app/views/**/*.rb
  ].freeze

  PROP_START_RE = /^\s*prop\s+:\w+\s*,/
  COLLECTION_PROXY_RE = /ActiveRecord::Associations::CollectionProxy/

  def test_no_collection_proxy_phlex_props
    offenders = scan_for_collection_proxy_props
    assert_empty(offenders, build_failure_message(offenders))
  end

  # --- Unit tests for the scanner itself ------------------------

  def test_scanner_flags_collection_proxy_in_union
    assert_bad(<<~RUBY)
      prop :versions,
           _Union(Array, ActiveRecord::Associations::CollectionProxy),
           default: -> { [] }
    RUBY
  end

  def test_scanner_flags_collection_proxy_on_one_line
    assert_bad("prop :versions, ActiveRecord::Associations::CollectionProxy")
  end

  def test_scanner_allows_array_only
    assert_clean("prop :versions, _Array(_Interface(:user_id))")
  end

  def test_scanner_ignores_non_prop_collection_proxy_mentions
    # A reference in a method body or a comment isn't a prop
    # declaration — leave it alone.
    assert_clean(<<~RUBY)
      # Returns an ActiveRecord::Associations::CollectionProxy.
      def versions
        @obj.versions
      end
    RUBY
  end

  private

  def assert_bad(snippet)
    lines = snippet.lines
    offenders = scan_file("test.rb", lines)
    assert_not_empty(offenders, "expected scanner to flag:\n#{snippet}")
  end

  def assert_clean(snippet)
    lines = snippet.lines
    offenders = scan_file("test.rb", lines)
    assert_empty(offenders, "expected scanner to allow:\n#{snippet}")
  end

  def scan_for_collection_proxy_props
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
      if statement.match?(COLLECTION_PROXY_RE)
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
  # `prop` statement is complete. The statement ends when paren
  # depth is back to zero AND the current line doesn't end with a
  # trailing comma (continuation marker). Returns the joined text,
  # the number of lines consumed, and the 1-based starting line
  # number.
  def collect_statement(lines, start_idx)
    text = +""
    j = start_idx
    depth = 0
    loop do
      line = lines[j]
      text << line
      depth += line.count("(") - line.count(")")
      j += 1
      break if j >= lines.length
      next unless depth <= 0

      stripped = line.rstrip
      break unless stripped.end_with?(",")
    end
    [text, j - start_idx, start_idx + 1]
  end

  def build_failure_message(offenders)
    return "" if offenders.empty?

    rendered = offenders.map do |o|
      "  #{o[:path]}:#{o[:line]}: #{o[:snippet]}"
    end
    <<~MSG
      `ActiveRecord::Associations::CollectionProxy` in a Phlex prop
      type — blocked.

      This shape papers over a caller that should `.to_a` its
      collection at the render site. Replace the prop type with
      `_Array(_Interface(:method_name))` (or a concrete class) and
      update callers to pass `obj.collection.to_a`.

      Offenders:
      #{rendered.join("\n")}
    MSG
  end
end

# frozen_string_literal: true

require("test_helper")

# Guards against the "Phlex view runs a DB query" anti-pattern.
# Scans every `app/components/**/*.rb` and `app/views/**/*.rb` file
# for ActiveRecord query-builder calls and fails if any are found.
# Controllers (or services they call) are expected to pre-load every
# record / collection the views render; views should accept them as
# props and iterate.
#
# What we flag: high-signal `.includes(...)`, `.where(...)`,
# `.joins(...)`, `.find_by(...)`, `.find_or_create_by(...)`,
# `.find_or_initialize_by(...)`, `.eager_load(...)`, `.preload(...)`,
# `.references(...)`, `.distinct(`, `.order(`, `.group(`, and
# `.exists?(...)` method calls.
#
# What we leave alone:
#   - `.all`, `.first`, `.last`, `.count`, `.size` — these have
#     legitimate Enumerable-on-Array variants that statically look
#     identical to the AR call, so flagging would flood the output
#     with false positives. The real-world cases I've seen all
#     route through one of the blocklisted methods above before
#     they get here.
#   - ERB files (`*.erb`). The user explicitly excluded them — this
#     guard is about cleanly-Phlexified views.
#   - `Query::Filter.all` — in-memory list of static filter defs,
#     not a DB query.
class NoQueriesInPhlexViewsTest < ActiveSupport::TestCase
  PHLEX_GLOBS = %w[
    app/components/**/*.rb
    app/views/**/*.rb
  ].freeze

  # Each pattern matches the method name with a leading `.` and an
  # opening `(` (or word boundary, for the `.distinct` shape). The
  # `\.` requires receiver chaining — bare `where(...)` calls in
  # controllers / scopes wouldn't match.
  QUERY_PATTERNS = [
    /\.includes\(/,
    /\.where\(/,
    /\.joins\(/,
    /\.find_by\(/,
    /\.find_or_create_by\(/,
    /\.find_or_initialize_by\(/,
    /\.eager_load\(/,
    /\.preload\(/,
    /\.references\(/,
    /\.distinct\b/,
    /\.order\(/,
    /\.group\(/,
    /\.exists\?\(/
  ].freeze

  # `Query::Filter.all` is the documented exception — it returns
  # the static array of filter definitions registered at load time
  # via `Query::Filter::Decimal`, etc. Not a DB query.
  ALLOWED_FRAGMENTS = [
    "Query::Filter.all"
  ].freeze

  def test_no_queries_in_phlex_views
    offenders = scan_for_queries
    assert_empty(offenders, build_failure_message(offenders))
  end

  # --- Unit tests for the scanner itself ------------------------

  def test_scanner_flags_bare_query_methods
    assert_bad("@object.descriptions.includes(:user).to_a")
    assert_bad("::Comment.where(target: @target).to_a")
    assert_bad("NameTracker.find_by(name_id: 1, user_id: 2)")
    assert_bad("@project.trackers.order(id: :desc)")
    assert_bad("Location.where(name: x).index_by(&:name)")
    assert_bad("@visual_model.visual_groups.order(:name)")
    assert_bad("Foo.find_or_create_by(slug: 'x')")
    assert_bad("Foo.preload(:bar)")
  end

  def test_scanner_does_not_flag_bare_all
    # `.all` (and `.first`, `.last`) match both Enumerable and
    # AR. We don't flag them statically — too many false positives.
    # Real-world AR query chains tend to compose them with one of
    # the blocklisted methods (`.where(...).all`, `.includes(...).first`),
    # which IS caught.
    assert_clean("Language.all.map { |l| l }")
    assert_clean("@items.first.name")
  end

  def test_scanner_allows_in_memory_array_calls
    assert_clean("@items.find { |i| i.id == 1 }") # Enumerable#find with block
    assert_clean("@list.first")
    assert_clean("@list.size")
    assert_clean("class_names('p-3', attrs[:class])")
    assert_clean("@values.group_by(&:kind)") # Enumerable#group_by
  end

  def test_scanner_allows_documented_exceptions
    assert_clean("Query::Filter.all.each { |f| render(f) }")
  end

  def test_scanner_flags_query_inside_comment_excluded
    assert_clean("# @object.descriptions.includes(:user)")
    assert_clean("    # Use Foo.where(bar: 1) instead.")
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

  def scan_for_queries
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
      next if ALLOWED_FRAGMENTS.any? { |f| stripped.include?(f) }

      QUERY_PATTERNS.each do |re|
        next unless stripped.match?(re)

        offenders << {
          path: rel, line: idx + 1, snippet: raw.strip
        }
        break
      end
    end
    offenders
  end

  def comment_line?(line)
    line.lstrip.start_with?("#")
  end

  # Drop everything from the first `#` outside a string literal.
  # Simple heuristic — good enough for source we control.
  def strip_inline_comment(line)
    in_str = nil
    out = +""
    line.each_char do |c|
      if in_str
        in_str = nil if c == in_str
        out << c
      elsif c == '"' || c == "'"
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
      ActiveRecord query-builder calls found in Phlex view/component
      files. Views should not run database queries — controllers (or
      the services they call) must pre-load every record / collection
      the view renders and pass them in as props.

      Blocklisted method patterns: #{QUERY_PATTERNS.map(&:source).join(", ")}

      Documented exceptions (in-memory): #{ALLOWED_FRAGMENTS.join(", ")}

      Offenders:
      #{rendered.join("\n")}
    MSG
  end
end

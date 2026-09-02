#!/usr/bin/env ruby
# frozen_string_literal: true

# Prints MO Article changelog rows (Textile) for the PRs merged in a
# date range, from the changelog block each PR body carries (see
# .claude/rules/changelog.md): `article: yes` PRs become rows, using
# the block's sentence; `article: no` PRs are counted; PRs with no
# parseable block are listed on stderr for a human to judge. Nothing
# is written anywhere -- paste the rows into the article by hand.
#
#   script/article_rows.rb --since 2026-08-22 [--until 2026-08-31]
#
# Rows come out newest first, in the article's table format, with the
# date cell marked nowrap so the link column cannot squeeze it.

require("date")
require("json")
require("open3")

# Turns merged PRs' changelog blocks into Textile article rows.
class ArticleRows
  USAGE = "Usage: script/article_rows.rb --since YYYY-MM-DD " \
          "[--until YYYY-MM-DD]"
  REPO = "MushroomObserver/mushroom-observer"
  BLOCK = %r{<!--\s*changelog\s*-->(.*?)<!--\s*/changelog\s*-->}m
  # GitHub search returns at most this many results per query.
  SEARCH_CAP = 1000
  # Longer sentences wrap the article's table.
  MAX_SENTENCE = 60

  # With argv: the CLI (date-ranged, fetches PRs itself). Without:
  # library use -- script/prerelease.rb hands rows_for a PR set it
  # already holds.
  def initialize(argv = nil)
    @since = nil
    @until = Date.today # rubocop:disable Rails/Date -- plain Ruby, no zone
    return unless argv

    parse_args(argv)
    abort(USAGE) unless @since
    abort("--until #{@until} is before --since #{@since}.") if @until < @since
  end

  def run
    pulls = merged_pulls.sort_by { |pull| pull["mergedAt"] }.reverse
    rows, skipped, blockless = classify(pulls)
    puts(rows)
    warn("#{rows.size} row(s); #{skipped} PR(s) marked article: no.")
    report_blockless(blockless)
  end

  # [rows, article-no count, blockless pulls] for an explicit PR set.
  def rows_for(pulls)
    classify(pulls.sort_by { |pull| pull["mergedAt"].to_s }.reverse)
  end

  private

  def parse_args(argv)
    args = argv.dup
    until args.empty?
      case (arg = args.shift)
      when "--since" then @since = parse_date(args.shift)
      when "--until" then @until = parse_date(args.shift)
      else abort("Unknown argument: #{arg}\n#{USAGE}")
      end
    end
  end

  def parse_date(value)
    Date.parse(value.to_s)
  rescue ArgumentError
    abort("Not a date: #{value.inspect}\n#{USAGE}")
  end

  def classify(pulls)
    rows = []
    skipped = 0
    blockless = []
    pulls.each do |pull|
      verdict, sentence = parse_block(pull["body"])
      case verdict
      when "yes" then rows << row(pull, sentence)
      when "no" then skipped += 1
      else blockless << pull
      end
    end
    [rows, skipped, blockless]
  end

  # [verdict, sentence]; verdict nil when the block is absent or does
  # not parse, the same rule the rules file states. The last block in
  # the body counts: a description may quote an example block above it.
  def parse_block(body)
    match = body.to_s.scan(BLOCK).last
    return [nil, nil] unless match

    lines = match[0].lines.map(&:strip).reject(&:empty?)
    verdict = lines.shift.to_s[/\Aarticle:\s*(yes|no)\z/i, 1]&.downcase
    sentence = lines.join(" ")
    usable?(verdict, sentence) ? [verdict, sentence] : [nil, nil]
  end

  # A yes with nothing to say is not a usable block either.
  def usable?(verdict, sentence)
    verdict == "no" || (verdict == "yes" && !sentence.empty?)
  end

  def row(pull, sentence)
    sentence = sentence.sub(/[.!]\z/, "")
    if sentence.length > MAX_SENTENCE
      warn("PR##{pull["number"]}: sentence is #{sentence.length} chars " \
           "(over #{MAX_SENTENCE}); trim it.")
    end
    %(|{white-space:nowrap}. #{pull["mergedAt"][0, 10]} | #{sentence} | ) +
      %("PR##{pull["number"]}":#{pull["url"]} |)
  end

  def report_blockless(pulls)
    return if pulls.empty?

    warn("\n#{pulls.size} PR(s) with no changelog block -- judge by hand:")
    pulls.each do |pull|
      warn("  PR##{pull["number"]} #{pull["mergedAt"][0, 10]} #{pull["title"]}")
    end
  end

  # Month by month: GitHub's search caps each query's results.
  def merged_pulls
    months.flat_map { |from, to| merged_in(from, to) }
  end

  # Calendar months: --since to the end of its month, then whole
  # months, the last one cut at --until.
  def months
    from = @since
    windows = []
    while from <= @until
      to = [Date.new(from.year, from.month, -1), @until].min
      windows << [from.iso8601, to.iso8601]
      from = to + 1
    end
    windows
  end

  def merged_in(from, to)
    pulls = JSON.parse(
      run_cmd("gh", "pr", "list", "--repo", REPO, "--state", "merged",
              "--limit", SEARCH_CAP.to_s, "--search", "merged:#{from}..#{to}",
              "--json", "number,title,url,mergedAt,body")
    )
    if pulls.size >= SEARCH_CAP
      abort("#{pulls.size} PRs merged in #{from}..#{to} hits GitHub's " \
            "search cap; use a shorter range.")
    end
    pulls
  end

  def run_cmd(*cmd)
    out, err, status = Open3.capture3(*cmd)
    abort("`#{cmd.join(" ")}` failed:\n#{err}") unless status.success?
    out
  end
end

ArticleRows.new(ARGV).run if $PROGRAM_NAME == __FILE__

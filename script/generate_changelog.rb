#!/usr/bin/env ruby
# frozen_string_literal: true

# Generates one CHANGELOG.md section per production deploy (issue
# #5155): a dated heading for a deploy-* tag with a flat list of every
# PR merged since the previous deploy tag. A PR belongs to a deploy
# when its merge commit is reachable from that deploy's tag but not
# from the previous one -- true for merge, squash and rebase merges
# alike, and for a stacked PR in the deploy where its parent landed.
# PR numbers, titles and authors come from one gh CLI call (run it
# wherever gh is authenticated).
#
#   Dry run (default -- prints the section(s), writes nothing):
#     script/generate_changelog.rb              # most recent deploy tag
#     script/generate_changelog.rb --tag deploy-2026-08-18-15-03
#     script/generate_changelog.rb --since deploy-2026-08-01-10-00
#   Apply (inserts into CHANGELOG.md, newest first):
#     script/generate_changelog.rb [--tag TAG | --since TAG] --apply
#   Regenerate sections already present (after a generator change):
#     script/generate_changelog.rb --since TAG --replace --apply
#
# --since TAG backfills one section for every deploy after TAG (TAG is
# the baseline, not itself listed). Sections are applied one at a time,
# so a failure mid-run keeps what was already written, and a rerun
# skips sections already present unless --replace is given.
#
# Standalone by design -- the deploy.sh hook comes later, once the
# format has settled.

require("date")
require("json")
require("open3")

# Builds and inserts one deploy's CHANGELOG.md section.
class ChangelogGenerator
  CHANGELOG = "CHANGELOG.md"
  TAG_PATTERN = /\Adeploy-(\d{4}-\d{2}-\d{2})-\d{2}-\d{2}\z/
  USAGE = "Usage: script/generate_changelog.rb " \
          "[--tag DEPLOY_TAG | --since DEPLOY_TAG] [--replace] [--apply]"
  HEADER = <<~MD
    # Changelog
  MD
  # A stacked PR can be merged into its parent branch long before the
  # parent reaches main; the PR pool reaches back this far before the
  # earliest deploy tag a run looks at.
  POOL_LOOKBACK_DAYS = 365

  def initialize(argv)
    @apply = false
    @replace = false
    @tag = nil
    @since = nil
    parse_args(argv)
  end

  def run
    tags = deploy_tags
    abort("No deploy-* tags found.") if tags.empty?
    @since ? run_since(tags) : run_single(tags)
  end

  private

  def parse_args(argv)
    args = argv.dup
    parse_arg(args.shift, args) until args.empty?
    abort("--tag and --since are mutually exclusive.\n#{USAGE}") if
      @tag && @since
  end

  def parse_arg(arg, rest)
    case arg
    when "--apply" then @apply = true
    when "--replace" then @replace = true
    when "--tag" then @tag = rest.shift || abort(USAGE)
    when "--since" then @since = rest.shift || abort(USAGE)
    else abort("Unknown argument: #{arg}\n#{USAGE}")
    end
  end

  def run_single(tags)
    target = @tag || tags.last
    index = tag_index(tags, target)
    abort("#{target} is the earliest deploy tag; no range.") if index.zero?

    @pool_from = tags[index - 1]
    @pool_to = target
    section = build_section(target, merged_prs(tags[index - 1], target))
    @apply ? apply(section, target) : puts(section)
    dry_run_notice unless @apply
  end

  def run_since(tags)
    index = tag_index(tags, @since)
    targets = tags[(index + 1)..]
    abort("No deploy tags after #{@since}.") if targets.empty?

    @pool_from = @since
    @pool_to = targets.last
    targets.each_with_index do |target, i|
      warn("[#{i + 1}/#{targets.size}] #{target}")
      generate(tags[index + i], target)
    end
    dry_run_notice unless @apply
  end

  def generate(prev_tag, target)
    if present?(target) && !@replace
      return warn("  skipped: already in #{CHANGELOG} (--replace to redo).")
    end

    section = build_section(target, merged_prs(prev_tag, target))
    @apply ? apply(section, target) : puts(section)
  end

  def tag_index(tags, tag)
    tags.index(tag) ||
      abort("#{tag} is not a deploy-* tag (git fetch --tags?).")
  end

  # Zero-padded date-stamped names, so name order is date order.
  def deploy_tags
    run_cmd("git", "tag", "-l", "deploy-*").split("\n").
      grep(TAG_PATTERN).sort
  end

  # PRs whose merge commit is in prev..target, in commit order.
  def merged_prs(prev_tag, target_tag)
    order = run_cmd("git", "rev-list", "--reverse",
                    "#{prev_tag}..#{target_tag}").
            split("\n").each_with_index.to_h
    pr_pool.select { |pull| order.key?(merge_sha(pull)) }.
      sort_by { |pull| order[merge_sha(pull)] }
  end

  def merge_sha(pull)
    pull.dig("mergeCommit", "oid")
  end

  # Every merged PR from POOL_LOOKBACK_DAYS before the run's earliest
  # tag onward, fetched once. Month by month: GitHub's search returns
  # at most 1000 results, ordered by creation, so a single query drops
  # old PRs that merged recently.
  def pr_pool
    @pr_pool ||= pool_months.flat_map do |from, to|
      JSON.parse(
        run_cmd("gh", "pr", "list", "--state", "merged", "--limit", "1000",
                "--search", "merged:#{from}..#{to}",
                "--json", "number,title,author,mergeCommit")
      )
    end
  end

  # Month windows from the lookback before the run's earliest tag to
  # its newest tag's date (nothing merged later can be in range).
  def pool_months
    from = tag_date(@pool_from) - POOL_LOOKBACK_DAYS
    last = tag_date(@pool_to)
    months = []
    while from <= last
      to = from.next_month - 1
      months << [from.iso8601, to.iso8601]
      from = to + 1
    end
    months
  end

  def tag_date(tag)
    Date.parse(run_cmd("git", "log", "-1", "--format=%cs", tag).strip)
  end

  def build_section(tag, prs)
    lines = ["## #{tag[TAG_PATTERN, 1]} (#{tag})", ""]
    lines += if prs.empty?
               ["(no merged PRs -- asset-only or config deploy)"]
             else
               prs.map { |info| pr_line(info) }
             end
    "#{lines.join("\n")}\n"
  end

  # A bare #NNNN, which GitHub autolinks in-repo. Not a markdown link
  # to the PR: a file full of those makes Copilot code review fail on
  # every PR in the repo.
  def pr_line(info)
    "- #{info["title"]} (##{info["number"]}, @#{info.dig("author", "login")})"
  end

  def dry_run_notice
    range = if @since then " --since #{@since}"
            elsif @tag then " --tag #{@tag}"
            end
    replace = " --replace" if @replace
    warn("Dry run - nothing written. To apply: " \
         "script/generate_changelog.rb#{range}#{replace} --apply")
  end

  def changelog_content
    File.exist?(CHANGELOG) ? File.read(CHANGELOG) : HEADER
  end

  def present?(tag)
    changelog_content.include?("(#{tag})")
  end

  def apply(section, tag)
    content = changelog_content
    if present?(tag)
      unless @replace
        abort("#{CHANGELOG} already has a section for #{tag} (--replace " \
              "to redo).")
      end
      File.write(CHANGELOG, replace_section(content, section, tag))
      warn("Replaced #{tag} section in #{CHANGELOG}.")
    else
      File.write(CHANGELOG, insert_sorted(content, section, tag))
      warn("Inserted #{tag} section into #{CHANGELOG}.")
    end
  end

  # Sections run newest first. Insert above the first existing section
  # older than this tag, so historical tags can be applied in any
  # order; a tag newer than everything lands right under the header,
  # and one older than everything appends at the end.
  def insert_sorted(content, section, tag)
    older = section_positions(content).find { |_pos, t| t < tag }
    if older
      "#{content[0...older[0]]}#{section}\n#{content[older[0]..]}"
    else
      "#{content.chomp}\n\n#{section}"
    end
  end

  # Swap the section for this tag, heading through the line before the
  # next heading (or end of file).
  def replace_section(content, section, tag)
    positions = section_positions(content)
    i = positions.index { |_pos, t| t == tag }
    start = positions[i][0]
    tail = positions[i + 1] ? content[positions[i + 1][0]..] : ""
    "#{content[0...start]}#{section}#{"\n#{tail}" unless tail.empty?}"
  end

  # [offset, deploy-tag] for each section heading, in file order.
  def section_positions(content)
    positions = []
    content.scan(/^## \d{4}-\d{2}-\d{2} \((deploy-[0-9-]+)\)/) do
      positions << [Regexp.last_match.begin(0), Regexp.last_match[1]]
    end
    positions
  end

  def run_cmd(*cmd)
    out, err, status = Open3.capture3(*cmd)
    abort("`#{cmd.join(" ")}` failed:\n#{err}") unless status.success?
    out
  end
end

ChangelogGenerator.new(ARGV).run

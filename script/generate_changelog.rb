#!/usr/bin/env ruby
# frozen_string_literal: true

# Generates one CHANGELOG.md section per production deploy (issue
# #5155): a dated heading for a deploy-* tag with a flat list of every
# PR merged since the previous deploy tag. PR titles/authors come
# from the gh CLI (run it wherever gh is authenticated); the PR list
# comes from the merge commits between the two tags.
#
#   Dry run (default -- prints the section(s), writes nothing):
#     script/generate_changelog.rb              # most recent deploy tag
#     script/generate_changelog.rb --tag deploy-2026-08-18-15-03
#     script/generate_changelog.rb --since deploy-2026-08-01-10-00
#   Apply (inserts into CHANGELOG.md, newest first):
#     script/generate_changelog.rb [--tag TAG | --since TAG] --apply
#
# --since TAG backfills one section for every deploy after TAG (TAG is
# the baseline, not itself listed). Sections are applied one at a time,
# so a gh failure mid-run keeps what was already written, and a rerun
# skips sections already present.
#
# Idempotent: --apply refuses to insert a section whose deploy tag is
# already present. Standalone by design -- the deploy.sh hook comes
# later, once the format has settled.

require("json")
require("open3")

# Builds and inserts one deploy's CHANGELOG.md section.
class ChangelogGenerator
  CHANGELOG = "CHANGELOG.md"
  TAG_PATTERN = /\Adeploy-(\d{4}-\d{2}-\d{2})-\d{2}-\d{2}\z/
  USAGE = "Usage: script/generate_changelog.rb " \
          "[--tag DEPLOY_TAG | --since DEPLOY_TAG] [--apply]"
  HEADER = <<~MD
    # Changelog
  MD

  def initialize(argv)
    @apply = false
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
    when "--tag" then @tag = rest.shift || abort(USAGE)
    when "--since" then @since = rest.shift || abort(USAGE)
    else abort("Unknown argument: #{arg}\n#{USAGE}")
    end
  end

  def run_single(tags)
    target = @tag || tags.last
    index = tag_index(tags, target)
    abort("#{target} is the earliest deploy tag; no range.") if index.zero?

    section = build_section(target, merged_prs(tags[index - 1], target))
    @apply ? apply(section, target) : puts(section)
    dry_run_notice unless @apply
  end

  def run_since(tags)
    index = tag_index(tags, @since)
    targets = tags[(index + 1)..]
    abort("No deploy tags after #{@since}.") if targets.empty?

    targets.each_with_index do |target, i|
      warn("[#{i + 1}/#{targets.size}] #{target}")
      generate(tags[index + i], target)
    end
    dry_run_notice unless @apply
  end

  def generate(prev_tag, target)
    return warn("  skipped: already in #{CHANGELOG}.") if present?(target)

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

  # git log lists newest first; reverse to merge order.
  def merged_prs(prev_tag, target_tag)
    run_cmd("git", "log", "--merges", "--format=%s",
            "#{prev_tag}..#{target_tag}").
      split("\n").
      filter_map { |subject| subject[/\AMerge pull request #(\d+)/, 1] }.
      reverse.
      map { |number| pr_info(number) }
  end

  def pr_info(number)
    JSON.parse(
      run_cmd("gh", "pr", "view", number,
              "--json", "number,title,author")
    )
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
    warn("Dry run - nothing written. To apply: " \
         "script/generate_changelog.rb#{range} --apply")
  end

  def changelog_content
    File.exist?(CHANGELOG) ? File.read(CHANGELOG) : HEADER
  end

  def present?(tag)
    changelog_content.include?("(#{tag})")
  end

  def apply(section, tag)
    abort("CHANGELOG.md already has a section for #{tag}.") if present?(tag)

    File.write(CHANGELOG, insert_sorted(changelog_content, section, tag))
    warn("Inserted #{tag} section into #{CHANGELOG}.")
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

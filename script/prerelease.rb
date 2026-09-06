#!/usr/bin/env ruby
# frozen_string_literal: true

# Creates or updates the pre-deploy changelog PR (issue #5155). Run it
# before a deploy; merge the PR it makes as the last PR, then deploy.
#
#   Dry run (default -- prints what the PR would contain):
#     script/prerelease.rb
#   Apply (pushes the changelog-pending branch, creates/updates the PR):
#     script/prerelease.rb --apply
#
# Deploy-tag time (all UTC):
#   default            the next 12:00 UTC (today's noon if it hasn't
#                      passed, else tomorrow's)
#   --now              the current date and time
#   --at DATETIME      an explicit "YYYY-MM-DD" (noon) or
#                      "YYYY-MM-DD HH:MM"
#
# What it does:
# - mints the upcoming deploy tag name (deploy-YYYY-MM-DD-HH-MM) for
#   the target time above; deploy.sh tags with the name it finds in
#   CHANGELOG.md's top heading
# - builds the CHANGELOG.md section for every PR merged since the last
#   deploy tag (the changelog PR is left out of the section it creates)
# - writes article_pending.textile with the MO Article rows from the
#   PRs' changelog blocks; reviewers edit the rows there, and the
#   deploy applies the file as merged
# - re-running replaces the branch, the PR body, and any stale pending
#   section, so last-minute merges are picked up
#
# Works in a temporary git worktree; the current checkout stays put.

require("json")
require("open3")
require("tempfile")
require("tmpdir")
require_relative("generate_changelog")
require_relative("article_rows")

# Builds the changelog-pending branch and PR for the next deploy.
class Prerelease
  BRANCH = "changelog-pending"
  ARTICLE_FILE = "article_pending.textile"
  USAGE = "Usage: script/prerelease.rb [--apply] " \
          "[--now | --at 'YYYY-MM-DD[ HH:MM]']"

  def initialize(argv)
    args = argv.dup
    @apply = args.delete("--apply") ? true : false
    @now = args.delete("--now") ? true : false
    @at = extract_at(args)
    abort("--now and --at are mutually exclusive.\n#{USAGE}") if @now && @at
    abort("Unknown arguments: #{args.join(" ")}\n#{USAGE}") if args.any?
  end

  def run
    warn("Fetching tags and main from origin...")
    run_cmd("git", "fetch", "origin", "--tags")
    generator = ChangelogGenerator.new([])
    collect_pending(generator)
    @apply ? apply(generator) : preview
  end

  private

  # Pulls `--at VALUE` (and its value) out of args, returning the
  # parsed UTC Time or nil.
  def extract_at(args)
    i = args.index("--at")
    return nil unless i

    value = args[i + 1]
    abort("--at needs a value.\n#{USAGE}") unless value
    args.delete_at(i + 1)
    args.delete_at(i)
    parse_at(value)
  end

  # A bare date means noon UTC; a date+time is taken as UTC.
  def parse_at(value)
    case value
    when /\A(\d{4})-(\d{2})-(\d{2})\z/
      Time.utc(::Regexp.last_match(1).to_i, ::Regexp.last_match(2).to_i,
               ::Regexp.last_match(3).to_i, 12, 0)
    when /\A(\d{4})-(\d{2})-(\d{2})[ T](\d{2}):(\d{2})\z/
      Time.utc(*(1..5).map { |n| ::Regexp.last_match(n).to_i })
    else
      abort("Bad --at value: #{value.inspect}. Use YYYY-MM-DD or " \
            "'YYYY-MM-DD HH:MM'.\n#{USAGE}")
    end
  end

  # deploy.sh stamps tags with the server's UTC clock, so all of these
  # are UTC -- a developer's local clock could otherwise mint a name
  # that sorts before the newest deployed tag.
  def deploy_time
    return Time.now.utc if @now
    return @at if @at

    next_noon_utc
  end

  # Today's 12:00 UTC if it hasn't passed (noon itself counts as not
  # passed), otherwise tomorrow's.
  def next_noon_utc
    now = Time.now.utc
    noon = Time.utc(now.year, now.month, now.day, 12, 0)
    now <= noon ? noon : noon + (24 * 60 * 60)
  end

  def collect_pending(generator)
    @tag = deploy_time.strftime("deploy-%Y-%m-%d-%H-%M")
    warn("Collecting merged PRs from GitHub (several queries; ~10-20s)...")
    @prev, @pulls = generator.pending_pulls(exclude_branch: BRANCH)
    abort("No PRs merged since #{@prev}; nothing to prepare.") if
      @pulls.empty?
    warn("Found #{@pulls.size} PR(s) merged since #{@prev}.\n\n")

    fresh_section = generator.pending_section(@tag, @pulls)
    @rows, @skipped, @blockless = ArticleRows.new.rows_for(@pulls)
    @section = merge_developer_edits(fresh_section)
  end

  # Preserve edits already made on the changelog-pending branch and add
  # only lines for PRs mentioned nowhere there, so a re-run does not
  # revert a reviewer's combined/reworded entries. A first run (no such
  # branch) or one whose pending content was already deployed starts
  # fresh. The heading is refreshed to the current @tag either way.
  def merge_developer_edits(fresh_section)
    existing = existing_pending_content
    unless existing
      @rows = existing_rows_merged(nil)
      return fresh_section
    end

    @rows = existing_rows_merged(existing[:rows])
    merge_section(fresh_section, existing[:bullets])
  end

  # [heading, "", *bullets] with the reviewer's bullets kept verbatim
  # and a line appended for each PR whose number appears in none of
  # them (matching PRNNNN and PR#NNNN).
  def merge_section(fresh_section, kept_bullets)
    heading = fresh_section.lines.first.chomp
    mentioned = pr_numbers(kept_bullets.join("\n"))
    additions = fresh_section.lines.map(&:chomp).
                select { |line| line.start_with?("- ") }.
                reject { |line| mentioned.include?(pr_number(line)) }
    "#{([heading, ""] + kept_bullets + additions).join("\n")}\n"
  end

  def existing_rows_merged(existing_rows)
    return @rows if existing_rows.nil?

    mentioned = pr_numbers(existing_rows.join("\n"))
    additions = @rows.reject { |row| mentioned.include?(pr_number(row)) }
    existing_rows + additions
  end

  # The changelog-pending branch's pending bullets and article rows, or
  # nil when there is no such branch or its top section was already
  # deployed (stale -- start fresh).
  def existing_pending_content
    lines = pending_changelog_lines
    return nil unless lines

    { bullets: section_bullets(lines), rows: pending_article_rows }
  end

  # The changelog-pending CHANGELOG.md as lines, or nil when there is
  # no such branch or its top section was already deployed (stale).
  def pending_changelog_lines
    changelog = show_branch_file(ChangelogGenerator::CHANGELOG)
    return nil unless changelog

    lines = changelog.lines.map(&:chomp)
    heading = lines.find { |line| line.start_with?("## ") }
    return nil unless heading

    tag = heading[/\((deploy-[0-9-]+)\)/, 1]
    tag && deployed_tag?(tag) ? nil : lines
  end

  def pending_article_rows
    (show_branch_file(ARTICLE_FILE)&.lines&.map(&:chomp) || []).
      reject(&:empty?)
  end

  # Bullet lines of the top section, up to the next heading or the end.
  def section_bullets(lines)
    start = lines.index { |line| line.start_with?("## ") }
    rest = lines[(start + 1)..]
    finish = rest.index { |line| line.start_with?("## ") }
    (finish ? rest[0...finish] : rest).select { |l| l.start_with?("- ") }
  end

  def show_branch_file(path)
    out, _err, status = Open3.capture3("git", "show",
                                       "origin/#{BRANCH}:#{path}")
    status.success? ? out : nil
  end

  def deployed_tag?(tag)
    out, _err, status = Open3.capture3("git", "tag", "-l", tag)
    status.success? && !out.strip.empty?
  end

  def pr_numbers(text) = text.scan(/PR#?(\d+)/).flatten

  def pr_number(line) = line[/PR#?(\d+)/, 1]

  def preview
    puts("Pending deploy: #{@tag}")
    puts
    puts("=== CHANGELOG.md section " \
         "(#{@pulls.size} PR(s) since #{@prev}) ===")
    puts
    puts(@section)
    puts
    puts
    puts("=== #{ARTICLE_FILE} (rows the deploy publishes to the " \
         "MO Article) ===")
    puts
    puts(@rows.empty? ? "(none - no article: yes PRs)" : @rows)
    puts
    preview_blockless
    puts("Dry run - nothing written. To apply: script/prerelease.rb --apply")
  end

  def preview_blockless
    return if @blockless.empty?

    puts("=== #{@blockless.size} PR(s) with no changelog block " \
         "(need a verdict) ===")
    puts
    @blockless.each do |pull|
      puts("  PR##{pull["number"]} #{pull["title"]}")
    end
    puts
  end

  def apply(generator)
    push_branch(generator)
    upsert_pr
  end

  def push_branch(generator)
    warn("Building #{BRANCH} in a temporary worktree...")
    Dir.mktmpdir("prerelease") do |tmp|
      dir = File.join(tmp, "wt")
      run_cmd("git", "worktree", "add", "--detach", dir, "origin/main")
      begin
        write_files(generator, dir)
        run_cmd("git", "-C", dir, "add",
                ChangelogGenerator::CHANGELOG, ARTICLE_FILE)
        run_cmd("git", "-C", dir, "commit", "-m", "Changelog for #{@tag}")
        run_cmd("git", "-C", dir, "push", "--force", "origin",
                "HEAD:refs/heads/#{BRANCH}")
        warn("Pushed #{BRANCH}.")
      ensure
        run_cmd("git", "worktree", "remove", "--force", dir)
      end
    end
  end

  def write_files(generator, dir)
    Dir.chdir(dir) do
      generator.apply_pending(@section, @tag)
      rows = @rows.empty? ? "" : "#{@rows.join("\n")}\n"
      File.write(ARTICLE_FILE, rows)
    end
  end

  # The temp file must outlive the gh call; Tempfile.create's block
  # guarantees that, then removes it.
  def upsert_pr
    Tempfile.create(["prerelease_pr_body", ".md"]) do |file|
      file.write(pr_body)
      file.flush
      submit_pr(file.path)
    end
  end

  def submit_pr(body_path)
    if (number = existing_pr)
      run_cmd("gh", "pr", "edit", number.to_s, "--title", title,
              "--body-file", body_path)
      warn("Updated PR ##{number} (#{BRANCH}).")
    else
      out = run_cmd("gh", "pr", "create", "--draft", "--head", BRANCH,
                    "--title", title, "--body-file", body_path)
      warn("Created #{out.strip}")
    end
  end

  def title
    "Changelog for `#{@tag}`"
  end

  def existing_pr
    out = run_cmd("gh", "pr", "list", "--head", BRANCH, "--state", "open",
                  "--json", "number")
    JSON.parse(out).first&.fetch("number")
  end

  def body_file
    path = File.join(Dir.tmpdir, "prerelease_pr_body.md")
    File.write(path, pr_body)
    path
  end

  def pr_body
    <<~BODY
      Pre-deploy changelog for `#{@tag}` (issue #5155): the CHANGELOG.md section for every PR merged since `#{@prev}`, and `#{ARTICLE_FILE}` with the MO Article rows the deploy will publish. Merge this as the last PR before deploying; re-running `script/prerelease.rb --apply` refreshes it with any later merges.

      ## Expected MO Article lines

      #{article_lines}

      #{verdict_section}<!-- changelog -->
      article: no
      <!-- /changelog -->
    BODY
  end

  def article_lines
    return "None - no `article: yes` PRs in this deploy." if @rows.empty?

    "```\n#{@rows.join("\n")}\n```\n(#{@skipped} PR(s) marked " \
      "`article: no`.) Edits to `#{ARTICLE_FILE}` in this PR are what " \
      "the deploy publishes."
  end

  def verdict_section
    return "" if @blockless.empty?

    list = @blockless.map do |pull|
      "- PR##{pull["number"]} #{pull["title"]}"
    end.join("\n")
    "## Needs a verdict (no changelog block)\n\n#{list}\n\n" \
      "To promote one, add a row to `#{ARTICLE_FILE}` in this PR.\n\n"
  end

  def run_cmd(*cmd)
    out, err, status = Open3.capture3(*cmd)
    abort("`#{cmd.join(" ")}` failed:\n#{err}") unless status.success?
    out
  end
end

Prerelease.new(ARGV).run if $PROGRAM_NAME == __FILE__

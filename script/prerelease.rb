#!/usr/bin/env ruby
# frozen_string_literal: true

# rubocop:disable MO/NoLongCommentBlock
# Creates or updates the pre-deploy changelog PR. Run it
# before a deploy; merge the PR it makes as the last PR, then deploy.
#
#   Dry run (default -- prints what the PR would contain):
#     script/prerelease.rb
#   Apply (pushes the changelog-pending branch, creates/updates the PR):
#     script/prerelease.rb --apply
#
# Deploy-tag time (the tag is stamped in UTC), the first that applies:
#   --now              the current date and time
#   --at TIME          e.g. 8pm, "08:00 tomorrow", "monday 9am UTC"; in
#                      this machine's time zone unless one is given (see
#                      script/deploy_time.rb for what it reads)
#   the open PR        the time in the changelog PR's tag, so a re-run
#                      during a deploy keeps it
#   otherwise          --apply asks for one; a dry run shows the time as
#                      ??-??
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
# - prints which open PRs may merge now (script/open_pull_requests.rb)
#   and which merged PRs in this deploy are review: blocker or urgent
# - with --apply, prints the first line to post in the site banner;
#   deploy.sh replaces it once the release is up
#
# Works in a temporary git worktree; the current checkout stays put.
# rubocop:enable MO/NoLongCommentBlock

require("json")
require("open3")
require("tempfile")
require("tmpdir")
require_relative("generate_changelog")
require_relative("article_rows")
require_relative("open_pull_requests")
require_relative("release_notes")
require_relative("prerelease_deploy_time")

# Builds the changelog-pending branch and PR for the next deploy.
class Prerelease
  BRANCH = "changelog-pending"
  ARTICLE_FILE = ReleaseNotes::PENDING_FILE
  BANNER_ADMIN_URL = "https://mushroomobserver.org/admin/banners"
  USAGE = "Usage: script/prerelease.rb [--apply] [--now | --at TIME]"

  def initialize(argv)
    args = argv.dup
    @apply = args.delete("--apply") ? true : false
    @now = args.delete("--now") ? true : false
    @at_text = extract_at(args)
    abort("--now and --at are mutually exclusive.\n#{USAGE}") if
      @now && @at_text
    abort("Unknown arguments: #{args.join(" ")}\n#{USAGE}") if args.any?
    @at = PrereleaseDeployTime.parse(@at_text) do |error|
      abort("#{error}\n#{USAGE}")
    end
  end

  def run
    warn("Fetching tags and main from origin...")
    run_cmd("git", "fetch", "origin", "--tags")
    # Before collect_pending, which aborts when nothing has merged -- the
    # open PRs matter most then.
    puts(OpenPullRequests.fetch.report, "")
    @pending_pr = find_pending_pr
    generator = ChangelogGenerator.new([])
    collect_pending(generator)
    puts(OpenPullRequests.urgent_merges_report(@pulls))
    @apply ? apply(generator) : preview
  end

  private

  # Pulls `--at VALUE` (and its value) out of args, returning the value
  # or nil.
  def extract_at(args)
    i = args.index("--at")
    return nil unless i

    value = args[i + 1]
    abort("--at needs a value.\n#{USAGE}") unless value
    args.delete_at(i + 1)
    args.delete_at(i)
    value
  end

  def resolve_deploy_time
    choice = PrereleaseDeployTime.new(
      now: @now, at: @at, at_text: @at_text, pending_pr: @pending_pr,
      apply: @apply
    )
    @deploy_time = choice.time
    @tag = choice.tag
    puts(choice.report, "")
  end

  def collect_pending(generator)
    warn("Collecting merged PRs from GitHub (several queries; ~10-20s)...")
    @prev, @pulls = generator.pending_pulls(exclude_branch: BRANCH)
    abort("No PRs merged since #{@prev}; nothing to prepare.") if
      @pulls.empty?
    warn("Found #{@pulls.size} PR(s) merged since #{@prev}.\n\n")
    resolve_deploy_time

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
    return sort_rows_by_date(@rows) if existing_rows.nil?

    mentioned = pr_numbers(existing_rows.join("\n"))
    additions = @rows.reject { |row| mentioned.include?(pr_number(row)) }
    sort_rows_by_date(existing_rows + additions)
  end

  # Keep the article rows newest-first by their date cell (matching
  # ArticleRows and the changelog convention) so appended PRs don't land
  # out of order. Stable within a date, and rows with no parseable date
  # sort to the end.
  def sort_rows_by_date(rows)
    rows.each_with_index.sort do |(row_a, idx_a), (row_b, idx_b)|
      by_date = row_date(row_b) <=> row_date(row_a)
      by_date.zero? ? (idx_a <=> idx_b) : by_date
    end.map(&:first)
  end

  def row_date(row)
    row[/\{white-space:nowrap\}\.\s*(\d{4}-\d{2}-\d{2})/, 1].to_s
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
    puts(pending_deploy_line)
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

  def pending_deploy_line
    return "No pending deploy" unless @pending_pr

    tag = @pending_pr["title"][/deploy-[0-9-]+/] || @pending_pr["title"]
    "Pending deploy: #{tag} (PR ##{@pending_pr["number"]})"
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
    puts("", "Replace the banner's first line at #{BANNER_ADMIN_URL} with:",
         "", "#{ReleaseNotes.pending_banner_line(@deploy_time)}<br/>")
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
    if (number = @pending_pr&.fetch("number"))
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

  # The open changelog PR's number and title, or nil.
  def find_pending_pr
    out = run_cmd("gh", "pr", "list", "--head", BRANCH, "--state", "open",
                  "--json", "number,title")
    JSON.parse(out).first
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

  def run_cmd(*cmd) = GithubCLI.run(*cmd)
end

Prerelease.new(ARGV).run if $PROGRAM_NAME == __FILE__

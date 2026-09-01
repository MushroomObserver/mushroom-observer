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
# What it does:
# - mints the upcoming deploy tag name (deploy-YYYY-MM-DD-HH-MM, from
#   the current time); deploy.sh tags with the name it finds in
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
require("tmpdir")
require_relative("generate_changelog")
require_relative("article_rows")

# Builds the changelog-pending branch and PR for the next deploy.
class Prerelease
  BRANCH = "changelog-pending"
  ARTICLE_FILE = "article_pending.textile"
  USAGE = "Usage: script/prerelease.rb [--apply]"

  def initialize(argv)
    args = argv.dup
    @apply = args.delete("--apply") ? true : false
    abort("Unknown arguments: #{args.join(" ")}\n#{USAGE}") if args.any?
  end

  def run
    run_cmd("git", "fetch", "origin", "--tags")
    # Local time, matching deploy.sh's `date "+deploy-%Y-%m-%d-%H-%M"`.
    @tag = Time.now. # rubocop:disable Rails/TimeZone -- plain Ruby
           strftime("deploy-%Y-%m-%d-%H-%M")
    generator = ChangelogGenerator.new([])
    @prev, pulls = generator.pending_pulls(exclude_branch: BRANCH)
    abort("No PRs merged since #{@prev}; nothing to prepare.") if pulls.empty?

    @section = generator.pending_section(@tag, pulls)
    @rows, @skipped, @blockless = ArticleRows.new.rows_for(pulls)
    @apply ? apply(generator) : preview
  end

  private

  def preview
    puts(@section)
    puts("-- #{ARTICLE_FILE} --")
    puts(@rows.empty? ? "(no article rows)" : @rows)
    warn_blockless
    warn("Dry run - nothing written. To apply: script/prerelease.rb --apply")
  end

  def warn_blockless
    return if @blockless.empty?

    warn("#{@blockless.size} PR(s) with no changelog block " \
         "(listed in the PR body for a verdict):")
    @blockless.each do |pull|
      warn("  PR##{pull["number"]} #{pull["title"]}")
    end
  end

  def apply(generator)
    push_branch(generator)
    upsert_pr
  end

  def push_branch(generator)
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

  def upsert_pr
    number = existing_pr
    if number
      run_cmd("gh", "pr", "edit", number.to_s, "--title", title,
              "--body-file", body_file)
      warn("Updated PR ##{number} (#{BRANCH}).")
    else
      out = run_cmd("gh", "pr", "create", "--draft", "--head", BRANCH,
                    "--title", title, "--body-file", body_file)
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

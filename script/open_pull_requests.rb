#!/usr/bin/env ruby
# frozen_string_literal: true

# Summarizes open, ready-for-review PRs by review type and lists the ones
# whose type allows merging now. The types and their merge rules are
# defined in .claude/rules/review_types.md.
#
#   script/open_pull_requests.rb
#
# script/prerelease.rb prints the same summary. Read-only: it queries
# GitHub and writes nothing.

require("json")
require("open3")
require("time")

# Classifies open PRs as mergeable now or still waiting.
class OpenPullRequests
  LABEL_PREFIX = "review: "
  TYPES = ["blocker", "urgent", "standard", "needs review"].freeze
  DEFAULT_TYPE = "standard"
  UNCLEAR_TYPE = "unclear"
  STANDARD_WAIT = 24 * 60 * 60
  EXCLUDED_BRANCH = "changelog-pending"
  TITLE_WIDTH = 50
  NO_LABEL = "no review label"
  MERGE_STATE_UNKNOWN = "merge state unknown - rerun"

  QUERY = <<~GRAPHQL
    query($owner: String!, $name: String!) {
      repository(owner: $owner, name: $name) {
        pullRequests(states: OPEN, first: 100) {
          pageInfo { hasNextPage }
          nodes {
            number title isDraft createdAt headRefName mergeable
            author { login }
            labels(first: 30) { nodes { name } }
            latestOpinionatedReviews(first: 30) {
              nodes { state submittedAt author { __typename } }
            }
            timelineItems(itemTypes: [READY_FOR_REVIEW_EVENT], last: 1) {
              nodes { ... on ReadyForReviewEvent { createdAt } }
            }
            commits(last: 1) {
              nodes { commit { statusCheckRollup { state } } }
            }
          }
        }
      }
    }
  GRAPHQL

  Pull = Data.define(:number, :title, :author, :type, :label_problem,
                     :ready_at, :approved, :changes_requested, :ci,
                     :mergeable)

  # [type, problem] from a PR's label names. No review label means the
  # default type; several, or one this script doesn't know, make the type
  # unclear, which holds the PR until the labels are fixed.
  def self.review_type(label_names)
    names = label_names.select { |name| name.start_with?(LABEL_PREFIX) }.
            map { |name| name.delete_prefix(LABEL_PREFIX) }
    return [DEFAULT_TYPE, NO_LABEL] if names.empty?
    return [UNCLEAR_TYPE, "multiple review labels"] if names.size > 1
    return [UNCLEAR_TYPE, "unknown review label"] unless
      TYPES.include?(names.first)

    [names.first, nil]
  end

  # Merged PRs (gh pr list JSON, with labels) typed blocker or urgent, so
  # whoever deploys knows what is riding along. Empty when there are none.
  def self.urgent_merges_report(merged)
    lines = merged.filter_map do |pull|
      names = pull["labels"].to_a.map { |label| label.fetch("name") }
      type = review_type(names).first
      if %w[blocker urgent].include?(type)
        "  PR##{pull["number"]} #{type} (@#{author_login(pull)}): " \
          "#{pull["title"]}"
      end
    end
    return [] if lines.empty?

    ["=== Blocker and urgent PRs in this deploy ===", "", *lines, ""]
  end

  # GitHub returns no author for a deleted account and shows it as "ghost".
  def self.author_login(pull)
    pull.dig("author", "login") || "ghost"
  end

  # GitHub computes merge conflicts lazily, and a query tends to start the
  # computation, so one pause and re-query usually resolves UNKNOWN.
  def self.fetch(now: Time.now.utc)
    connection = query_pulls
    if merge_state_pending?(connection["nodes"])
      warn("Waiting for GitHub to compute merge conflicts...")
      sleep(merge_state_retry_delay)
      connection = query_pulls
    end
    warn("More than 100 open PRs; the summary covers the first 100.") if
      connection.dig("pageInfo", "hasNextPage")
    new(connection["nodes"], now: now)
  end

  def self.query_pulls
    out, err, status = Open3.capture3(
      "gh", "api", "graphql", "-F", "owner={owner}", "-F", "name={repo}",
      "-f", "query=#{QUERY}"
    )
    abort("Open PR query failed:\n#{err}") unless status.success?
    JSON.parse(out).dig("data", "repository", "pullRequests")
  end

  def self.merge_state_pending?(nodes)
    nodes.any? { |node| !node["isDraft"] && node["mergeable"] == "UNKNOWN" }
  end

  def self.merge_state_retry_delay = 5

  attr_reader :pulls

  def initialize(nodes, now:)
    @now = now
    @pulls = nodes.reject { |node| skip?(node) }.map { |node| build(node) }.
             sort_by(&:ready_at)
  end

  def report
    lines = ["=== Open PRs ready for review (as of " \
             "#{@now.strftime("%Y-%m-%d %H:%M")} UTC) ===", ""]
    return (lines << "(none)").join("\n") if @pulls.empty?

    mergeable, waiting = @pulls.partition { |pull| mergeable?(pull) }
    lines.concat(section("Can merge now", mergeable))
    lines.concat(section("Waiting", waiting))
    lines.concat(unlabeled_line)
    lines.join("\n")
  end

  def mergeable?(pull)
    hold_reasons(pull).empty?
  end

  private

  def skip?(node)
    node["isDraft"] || node["headRefName"] == EXCLUDED_BRANCH
  end

  def build(node)
    type, problem = self.class.review_type(
      node.dig("labels", "nodes").map { |label| label.fetch("name") }
    )
    ready = ready_at(node)
    states = current_review_states(node, ready)
    Pull.new(number: node["number"], title: node["title"],
             author: self.class.author_login(node), type: type,
             label_problem: problem, ready_at: ready,
             approved: states.include?("APPROVED"),
             changes_requested: states.include?("CHANGES_REQUESTED"),
             ci: ci_state(node), mergeable: node["mergeable"])
  end

  # A PR opened as ready has no ReadyForReviewEvent; its clock starts when
  # it was opened.
  def ready_at(node)
    event = node.dig("timelineItems", "nodes").first
    Time.parse(event ? event["createdAt"] : node["createdAt"]).utc
  end

  # Each person's latest approval or change request since the PR was last
  # marked ready. Moving a PR back to draft is how an author resets review
  # after a large change, so earlier reviews no longer apply. Bot reviews
  # don't count; GitHub already bars the author from approving.
  def current_review_states(node, ready)
    node.dig("latestOpinionatedReviews", "nodes").
      select { |review| review.dig("author", "__typename") == "User" }.
      select { |review| Time.parse(review.fetch("submittedAt")).utc >= ready }.
      map { |review| review.fetch("state") }
  end

  def ci_state(node)
    node.dig("commits", "nodes").first&.
      dig("commit", "statusCheckRollup", "state")
  end

  # Why the PR may not merge yet; empty when it may.
  def hold_reasons(pull)
    return [pull.label_problem] if pull.type == UNCLEAR_TYPE

    [(MERGE_STATE_UNKNOWN if pull.mergeable == "UNKNOWN"),
     *type_holds(pull)].compact
  end

  def type_holds(pull)
    case pull.type
    when "standard" then standard_holds(pull)
    when "needs review" then approval_holds(pull)
    else []
    end
  end

  def standard_holds(pull)
    return ["changes requested"] if pull.changes_requested
    return [] if pull.approved || @now >= pull.ready_at + STANDARD_WAIT

    hours = ((pull.ready_at + STANDARD_WAIT - @now) / 3600.0).ceil
    ["can merge in #{hours}h"]
  end

  def approval_holds(pull)
    return ["changes requested"] if pull.changes_requested

    pull.approved ? [] : ["needs approval"]
  end

  def section(heading, pulls)
    return [] if pulls.empty?

    ["#{heading}:", *pulls.map { |pull| line(pull) }, ""]
  end

  def unlabeled_line
    numbers = @pulls.select { |pull| pull.label_problem == NO_LABEL }.
              map { |pull| "PR##{pull.number}" }
    return [] if numbers.empty?

    ["No review label (treated as #{DEFAULT_TYPE}): #{numbers.join(", ")}"]
  end

  def line(pull)
    format("  PR#%<number>-5d %<type>-12s ready %<ready>s  %<author>s  " \
           "%<title>s%<notes>s",
           number: pull.number, type: pull.type,
           ready: pull.ready_at.strftime("%m-%d %H:%M"),
           author: "@#{pull.author}".ljust(author_width),
           title: truncate(pull.title), notes: notes(pull))
  end

  def author_width
    @author_width ||= @pulls.map { |pull| pull.author.length + 1 }.max
  end

  def notes(pull)
    list = [review_note(pull), ci_note(pull.ci),
            ("conflicts" if pull.mergeable == "CONFLICTING"),
            *hold_reasons(pull)].compact.uniq
    list.empty? ? "" : "  [#{list.join(", ")}]"
  end

  def review_note(pull)
    return "changes requested" if pull.changes_requested

    "approved" if pull.approved
  end

  def ci_note(state)
    case state
    when "SUCCESS" then "CI ok"
    when "FAILURE", "ERROR" then "CI failing"
    when "PENDING", "EXPECTED" then "CI running"
    end
  end

  def truncate(title)
    title.length > TITLE_WIDTH ? "#{title[0, TITLE_WIDTH - 3]}..." : title
  end
end

puts(OpenPullRequests.fetch.report) if $PROGRAM_NAME == __FILE__

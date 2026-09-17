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
  # Least to most cautious; a PR with several review labels takes the most
  # cautious one.
  TYPES = ["blocker", "urgent", "standard", "needs review"].freeze
  DEFAULT_TYPE = "standard"
  STANDARD_WAIT = 24 * 60 * 60
  EXCLUDED_BRANCH = "changelog-pending"
  TITLE_WIDTH = 50
  NO_LABEL = "no review label"

  QUERY = <<~GRAPHQL
    query($owner: String!, $name: String!) {
      repository(owner: $owner, name: $name) {
        pullRequests(states: OPEN, first: 100) {
          pageInfo { hasNextPage }
          nodes {
            number title isDraft createdAt headRefName mergeable
            labels(first: 30) { nodes { name } }
            latestOpinionatedReviews(first: 30) {
              nodes { state author { __typename } }
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

  Pull = Data.define(:number, :title, :type, :label_problem, :ready_at,
                     :approved, :changes_requested, :ci, :conflicts)

  # [type, problem] from a PR's label names. problem is nil when the PR has
  # one known review label; otherwise it names what's wrong, and the type
  # is the most cautious known label present, else the default.
  def self.review_type(label_names)
    names = label_names.select { |name| name.start_with?(LABEL_PREFIX) }.
            map { |name| name.delete_prefix(LABEL_PREFIX) }
    known = TYPES & names
    type = known.max_by { |name| TYPES.index(name) } || DEFAULT_TYPE
    [type, label_problem(names, known)]
  end

  def self.label_problem(names, known)
    return NO_LABEL if names.empty?
    return "unknown review label" if known.empty?

    "multiple review labels" if names.size > 1
  end

  # Merged PRs (gh pr list JSON, with labels) typed blocker or urgent, so
  # whoever deploys knows what is riding along. Empty when there are none.
  def self.urgent_merges_report(merged)
    lines = merged.filter_map do |pull|
      names = pull["labels"].to_a.map { |label| label.fetch("name") }
      type = review_type(names).first
      "  PR##{pull["number"]} #{type}: #{pull["title"]}" if
        %w[blocker urgent].include?(type)
    end
    return [] if lines.empty?

    ["=== Blocker and urgent PRs in this deploy ===", "", *lines, ""]
  end

  def self.fetch(now: Time.now.utc)
    out, err, status = Open3.capture3(
      "gh", "api", "graphql", "-F", "owner={owner}", "-F", "name={repo}",
      "-f", "query=#{QUERY}"
    )
    abort("Open PR query failed:\n#{err}") unless status.success?
    connection = JSON.parse(out).dig("data", "repository", "pullRequests")
    warn("More than 100 open PRs; the summary covers the first 100.") if
      connection.dig("pageInfo", "hasNextPage")
    new(connection["nodes"], now: now)
  end

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
    case pull.type
    when "blocker", "urgent" then true
    when "standard"
      !pull.changes_requested &&
        (pull.approved || @now >= pull.ready_at + STANDARD_WAIT)
    else
      pull.approved && !pull.changes_requested
    end
  end

  private

  def skip?(node)
    node["isDraft"] || node["headRefName"] == EXCLUDED_BRANCH
  end

  def build(node)
    type, problem = self.class.review_type(
      node.dig("labels", "nodes").map { |label| label.fetch("name") }
    )
    states = human_review_states(node)
    Pull.new(number: node["number"], title: node["title"], type: type,
             label_problem: problem, ready_at: ready_at(node),
             approved: states.include?("APPROVED"),
             changes_requested: states.include?("CHANGES_REQUESTED"),
             ci: ci_state(node), conflicts: node["mergeable"] == "CONFLICTING")
  end

  # A PR opened as ready has no ReadyForReviewEvent; its clock starts when
  # it was opened.
  def ready_at(node)
    event = node.dig("timelineItems", "nodes").first
    Time.parse(event ? event["createdAt"] : node["createdAt"]).utc
  end

  # Only a person's review counts; GitHub already bars the author from
  # approving.
  def human_review_states(node)
    node.dig("latestOpinionatedReviews", "nodes").
      select { |review| review.dig("author", "__typename") == "User" }.
      map { |review| review.fetch("state") }
  end

  def ci_state(node)
    node.dig("commits", "nodes").first&.
      dig("commit", "statusCheckRollup", "state")
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
    format("  PR#%<number>-5d %<type>-12s ready %<ready>s  %<title>s%<notes>s",
           number: pull.number, type: pull.type,
           ready: pull.ready_at.strftime("%m-%d %H:%M"),
           title: truncate(pull.title), notes: notes(pull))
  end

  def notes(pull)
    list = [review_note(pull), ci_note(pull.ci),
            ("conflicts" if pull.conflicts), inline_label_problem(pull),
            wait_note(pull)].compact
    list.empty? ? "" : "  [#{list.join(", ")}]"
  end

  # A missing label is listed once, after the sections.
  def inline_label_problem(pull)
    pull.label_problem unless pull.label_problem == NO_LABEL
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

  def wait_note(pull)
    return if mergeable?(pull) || pull.changes_requested
    return "needs approval" unless pull.type == "standard"

    hours = ((pull.ready_at + STANDARD_WAIT - @now) / 3600.0).ceil
    "can merge in #{hours}h"
  end

  def truncate(title)
    title.length > TITLE_WIDTH ? "#{title[0, TITLE_WIDTH - 3]}..." : title
  end
end

puts(OpenPullRequests.fetch.report) if $PROGRAM_NAME == __FILE__

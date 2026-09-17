# frozen_string_literal: true

require("test_helper")
require(Rails.root.join("script/open_pull_requests").to_s)

# Merge rules and report shape for script/open_pull_requests.rb, built
# from canned GraphQL nodes instead of a GitHub query.
class OpenPullRequestsTest < UnitTestCase
  NOW = Time.utc(2026, 9, 17, 12, 0)
  READY = "2026-09-16T18:00:00Z" # 18 hours before NOW
  NODE_DEFAULTS = {
    number: 1, title: "A change", labels: [], reviews: [], ready: READY,
    created: "2026-09-01T00:00:00Z", draft: false, branch: "some-branch",
    ci: "SUCCESS", mergeable: "MERGEABLE"
  }.freeze

  def test_review_type_from_labels
    assert_equal(["standard", "no review label"],
                 OpenPullRequests.review_type(["bug"]))
    assert_equal(["urgent", nil],
                 OpenPullRequests.review_type(["bug", "review: urgent"]))
    assert_equal(["needs review", "multiple review labels"],
                 OpenPullRequests.review_type(["review: needs review",
                                               "review: blocker"]),
                 "several labels take the most cautious")
    assert_equal(["standard", "unknown review label"],
                 OpenPullRequests.review_type(["review: someday"]))
  end

  def test_blocker_and_urgent_merge_any_time
    %w[blocker urgent].each do |type|
      assert(mergeable?(node(labels: ["review: #{type}"])),
             "#{type} merges any time")
    end
  end

  def test_standard_merges_after_24_hours_or_with_an_approval
    assert_not(mergeable?(node(labels: ["review: standard"])),
               "18 hours after ready")
    assert(mergeable?(node(labels: ["review: standard"],
                           ready: "2026-09-16T11:00:00Z")),
           "25 hours after ready")
    assert(mergeable?(node(labels: ["review: standard"],
                           reviews: [%w[APPROVED User]])),
           "an approval allows an early merge")
    assert_not(mergeable?(node(labels: ["review: standard"],
                               ready: "2026-09-10T00:00:00Z",
                               reviews: [%w[CHANGES_REQUESTED User]])),
               "requested changes are not silence")
  end

  def test_needs_review_requires_a_persons_approval
    labels = ["review: needs review"]
    old = "2026-08-01T00:00:00Z"

    assert_not(mergeable?(node(labels: labels, ready: old)),
               "time alone is not enough")
    assert_not(mergeable?(node(labels: labels,
                               reviews: [%w[APPROVED Bot]])),
               "a bot's approval does not count")
    assert(mergeable?(node(labels: labels, reviews: [%w[APPROVED User]])))
  end

  def test_the_clock_starts_at_the_ready_event_else_at_creation
    from_event = pulls(node(ready: READY)).first
    opened_ready = pulls(node(ready: nil,
                              created: "2026-09-15T00:00:00Z")).first

    assert_equal(Time.utc(2026, 9, 16, 18), from_event.ready_at)
    assert_equal(Time.utc(2026, 9, 15), opened_ready.ready_at)
  end

  def test_drafts_and_the_changelog_pr_are_left_out
    listed = pulls(node(number: 1), node(number: 2, draft: true),
                   node(number: 3, branch: "changelog-pending"))

    assert_equal([1], listed.map(&:number))
  end

  def test_report_sections_and_notes
    report = OpenPullRequests.new(
      [node(number: 10, labels: ["review: urgent"], ci: "FAILURE",
            mergeable: "CONFLICTING"),
       node(number: 20, title: "Standard change")],
      now: NOW
    ).report

    assert_match(/Can merge now:\n  PR#10 .*\[CI failing, conflicts\]/,
                 report)
    assert_match(/Waiting:\n  PR#20 .*Standard change  /, report)
    assert_match(/PR#20 .*\[CI ok, can merge in 6h\]/, report)
    assert_match(/No review label \(treated as standard\): PR#20$/, report)
  end

  def test_report_notes_approval_and_running_ci
    report = OpenPullRequests.new(
      [node(ci: "PENDING", reviews: [%w[APPROVED User]])], now: NOW
    ).report

    assert_match(/PR#1 .*\[approved, CI running\]/, report)
  end

  def test_fetch_builds_the_report_from_the_graphql_response
    response = { "data" => { "repository" => { "pullRequests" => {
      "pageInfo" => { "hasNextPage" => true }, "nodes" => [node(number: 7)]
    } } } }.to_json
    success = Struct.new(:success?).new(true)

    report = nil
    _out, err = capture_io do
      Open3.stub(:capture3, [response, "", success]) do
        report = OpenPullRequests.fetch(now: NOW)
      end
    end

    assert_equal([7], report.pulls.map(&:number))
    assert_match(/More than 100 open PRs/, err)
  end

  def test_fetch_aborts_when_the_query_fails
    failure = Struct.new(:success?).new(false)

    _out, err = capture_io do
      Open3.stub(:capture3, ["", "gh: not logged in", failure]) do
        assert_raises(SystemExit) { OpenPullRequests.fetch(now: NOW) }
      end
    end

    assert_match(/Open PR query failed:\ngh: not logged in/, err)
  end

  def test_report_with_nothing_open
    report = OpenPullRequests.new([node(draft: true)], now: NOW).report

    assert_match(/\(none\)\z/, report)
  end

  def test_urgent_merges_report
    merged = [
      { "number" => 1, "title" => "Hot fix",
        "labels" => [{ "name" => "review: blocker" }] },
      { "number" => 2, "title" => "Feature",
        "labels" => [{ "name" => "review: standard" }] },
      { "number" => 3, "title" => "Unlabeled", "labels" => [] }
    ]

    assert_equal(["=== Blocker and urgent PRs in this deploy ===", "",
                  "  PR#1 blocker: Hot fix", ""],
                 OpenPullRequests.urgent_merges_report(merged))
    assert_empty(OpenPullRequests.urgent_merges_report(merged.drop(1)))
  end

  private

  def mergeable?(node)
    report = OpenPullRequests.new([node], now: NOW)
    report.mergeable?(report.pulls.first)
  end

  def pulls(*nodes)
    OpenPullRequests.new(nodes, now: NOW).pulls
  end

  # A GraphQL pull request node; keywords override NODE_DEFAULTS.
  def node(**overrides)
    opts = NODE_DEFAULTS.merge(overrides)
    {
      "number" => opts[:number], "title" => opts[:title],
      "isDraft" => opts[:draft], "createdAt" => opts[:created],
      "headRefName" => opts[:branch], "mergeable" => opts[:mergeable],
      "labels" => { "nodes" => opts[:labels].map { |n| { "name" => n } } },
      "timelineItems" => { "nodes" => ready_events(opts[:ready]) },
      "commits" => { "nodes" => [ci_commit(opts[:ci])] }
    }.merge(reviews_field(opts[:reviews]))
  end

  def ready_events(ready)
    ready ? [{ "createdAt" => ready }] : []
  end

  def ci_commit(state)
    { "commit" => { "statusCheckRollup" => { "state" => state } } }
  end

  # reviews: [[state, author __typename], ...]
  def reviews_field(reviews)
    nodes = reviews.map do |state, kind|
      { "state" => state, "author" => { "__typename" => kind } }
    end
    { "latestOpinionatedReviews" => { "nodes" => nodes } }
  end
end

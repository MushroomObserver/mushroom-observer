# frozen_string_literal: true

require("test_helper")
require("query_extensions")

# tests of Query::Comments class to be included in QueryTest
class Query::CommentsTest < UnitTestCase
  include QueryExtensions

  def test_comment_all
    expects = Comment.index_order
    assert_query(expects, :Comment)
  end

  def test_comment_id_in_set
    set = Comment.order(id: :asc).last(2).pluck(:id)
    scope = Comment.id_in_set(set)
    assert_query_scope(set, scope, :Comment, id_in_set: set)
  end

  def test_comment_by_user
    expects = Comment.by_users(mary.id)
    assert_query(expects, :Comment, by_users: mary)
  end

  def test_comment_for_target
    obs = observations(:minimal_unknown_obs)
    expects = Comment.index_order.where(target_id: obs.id).distinct
    assert_query(expects, :Comment, target: { id: obs, type: :Observation })
    expects = Comment.index_order.target(obs).distinct
    assert_query(expects, :Comment, target: { id: obs, type: :Observation })
  end

  def test_comment_for_user
    expects = Comment.index_order.select { |c| c.target.user == mary }
    # expects = Comment.index_order.joins(:target).
    #           where(targets: { user_id: mary.id }).uniq
    assert_query(expects, :Comment, for_user: mary)
    assert_query([], :Comment, for_user: rolf)
  end

  def test_comment_in_set
    assert_query(
      [comments(:detailed_unknown_obs_comment).id,
       comments(:minimal_unknown_obs_comment_1).id],
      :Comment, id_in_set: [comments(:detailed_unknown_obs_comment).id,
                            comments(:minimal_unknown_obs_comment_1).id]
    )
  end

  def test_comment_pattern_search
    expects = Comment.index_order.
              where(Comment[:summary].matches("%unknown%").
                    or(Comment[:comment].matches("%unknown%"))).uniq
    assert_query(expects, :Comment, pattern: "unknown")
    expects = Comment.pattern("unknown").index_order
    assert_query(expects, :Comment, pattern: "unknown")
  end

  def test_comment_summary_has
    expects = Comment.summary_has("Let's").index_order
    assert_query(expects, :Comment, summary_has: "Let's")
  end

  def test_comment_content_has
    expects = Comment.content_has("really cool").index_order
    assert_query(expects, :Comment, content_has: "really cool")
  end
end

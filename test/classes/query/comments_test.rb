# frozen_string_literal: true

require("test_helper")

# tests of Query::Comments class to be included in QueryTest
module Query::CommentsTest
  def test_comment_all
    expects = Comment.index_order
    assert_query(expects, :Comment)
  end

  def test_comment_by_user
    expects = Comment.index_order.where(user_id: mary.id).distinct
    assert_query(expects, :Comment, by_user: mary)
  end

  def test_comment_for_target
    obs = observations(:minimal_unknown_obs)
    expects = Comment.index_order.where(target_id: obs.id).distinct
    assert_query(expects, :Comment, target: obs, type: "Observation")
  end

  def test_comment_for_user
    expects = Comment.index_order.select { |c| c.target.user == mary }
    # expects = Comment.index_order.joins(:target).
    #           where(targets: { user_id: mary.id }).uniq
    assert_query(expects, :Comment, for_user: mary)
    assert_query([], :Comment, for_user: rolf)
  end

  def test_comment_in_set
    assert_query([comments(:detailed_unknown_obs_comment).id,
                  comments(:minimal_unknown_obs_comment_1).id],
                 :Comment,
                 ids: [comments(:detailed_unknown_obs_comment).id,
                       comments(:minimal_unknown_obs_comment_1).id])
  end

  def test_comment_pattern_search
    expects = Comment.index_order.
              where(Comment[:summary].matches("%unknown%").
                    or(Comment[:comment].matches("%unknown%"))).uniq
    assert_query(expects, :Comment, pattern: "unknown")
  end
end

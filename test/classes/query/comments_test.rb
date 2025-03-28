# frozen_string_literal: true

require("test_helper")
require("query_extensions")

# tests of Query::Comments class to be included in QueryTest
class Query::CommentsTest < UnitTestCase
  include QueryExtensions

  def test_comment_all
    expects = Comment.order_by_default
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
    expects = [comments(:minimal_unknown_obs_comment_2),
               comments(:minimal_unknown_obs_comment_1)]
    scope = Comment.order_by_default.target(obs).distinct
    assert_query_scope(expects, scope,
                       :Comment, target: { type: :Observation, id: obs.id })
    scope = Comment.order_by_default.
            target(type: "Observation", id: obs.id).distinct
    assert_query_scope(expects, scope,
                       :Comment, target: { type: :Observation, id: obs.id })
  end

  # Query currently raises on invalid params, so we can't test this yet.
  # def test_comment_for_invalid_target
  #   glo = glossary_terms(:convex_glossary_term)
  #   scope = Comment.target(glo)
  #   assert_query_scope([], scope,
  #                      :Comment, target: { type: :GlossaryTerm, id: glo.id })
  #   scope = Comment.target(type: "GlossaryTerm", id: glo.id)
  #   assert_query_scope([], scope,
  #                      :Comment, target: { type: :GlossaryTerm, id: glo.id })
  # end

  def test_comment_types
    expects = [comments(:fungi_comment)]
    scope = Comment.types(:name)
    assert_query_scope(expects, scope, :Comment, types: :name)
    expects = [comments(:detailed_unknown_obs_comment),
               comments(:minimal_unknown_obs_comment_2),
               comments(:minimal_unknown_obs_comment_1)]
    scope = Comment.types(:observation).order_by_default
    assert_query_scope(expects, scope, :Comment, types: :observation)
  end

  def test_comment_for_user
    expects = [comments(:detailed_unknown_obs_comment),
               comments(:minimal_unknown_obs_comment_2),
               comments(:minimal_unknown_obs_comment_1)]
    scope = Comment.for_user(mary).order_by_default
    assert_query_scope(expects, scope, :Comment, for_user: mary)
    expects = [comments(:fungi_comment)]
    scope = Comment.for_user(rolf).order_by_default
    assert_query_scope(expects, scope, :Comment, for_user: rolf)
    expects = []
    scope = Comment.for_user(users(:zero_user)).order_by_default
    assert_query_scope(expects, scope, :Comment, for_user: users(:zero_user))
  end

  def test_comment_in_set
    set = [comments(:detailed_unknown_obs_comment).id,
           comments(:minimal_unknown_obs_comment_1).id]
    scope = Comment.id_in_set(set)
    assert_query_scope(set, scope, :Comment, id_in_set: set)
  end

  def test_comment_pattern_search
    expects = Comment.order_by_default.distinct.
              where(Comment[:summary].matches("%unknown%").
                    or(Comment[:comment].matches("%unknown%")))
    scope = Comment.pattern("unknown").order_by_default
    assert_query_scope(expects, scope, :Comment, pattern: "unknown")
  end

  def test_comment_summary_has
    expects = Comment.summary_has("Let's").order_by_default
    assert_query(expects, :Comment, summary_has: "Let's")
  end

  def test_comment_content_has
    expects = Comment.content_has("really cool").order_by_default
    assert_query(expects, :Comment, content_has: "really cool")
  end
end

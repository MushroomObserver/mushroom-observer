# frozen_string_literal: true

require("test_helper")
require("api2_extensions")

class API2::CommentsTest < UnitTestCase
  include API2Extensions

  def test_basic_comment_get
    do_basic_get_test(Comment)
  end

  # -----------------------------
  #  :section: Comment Requests
  # -----------------------------

  def test_getting_comments
    params = { method: :get, action: :comment }
    com1 = comments(:minimal_unknown_obs_comment_1)
    com2 = comments(:minimal_unknown_obs_comment_2)
    com3 = comments(:detailed_unknown_obs_comment)

    assert_api_pass(params.merge(id: com1.id))
    assert_api_results([com1])

    assert_api_pass(params.merge(created_at: "2006-03-02 21:16:00"))
    assert_api_results([com2])

    assert_api_pass(params.merge(updated_at: "2007-03-02 21:16:00"))
    assert_api_results([com3])

    expect = Comment.where(user: rolf) + Comment.where(user: dick)
    assert_api_pass(params.merge(user: "rolf,dick"))
    assert_api_results(expect.sort_by(&:id))

    expect = Comment.where(target_type: "Observation")
    assert_api_pass(params.merge(type: "Observation"))
    assert_api_results(expect.sort_by(&:id))

    assert_api_pass(params.merge(summary_has: "complicated"))
    assert_api_results([com2])

    assert_api_pass(params.merge(content_has: "really cool"))
    assert_api_results([com1])

    obs = observations(:minimal_unknown_obs)
    assert_api_pass(params.merge(target: "observation ##{obs.id}"))
    assert_api_results(obs.comments.sort_by(&:id))

    # APIKeys don't have comments
    assert_api_fail(params.merge(type: APIKey.name))
  end

  def test_posting_comments
    @user    = rolf
    @target  = names(:petigera)
    @summary = "misspelling"
    @content = "The correct one is 'Peltigera'."
    params = {
      method: :post,
      action: :comment,
      api_key: @api_key.key,
      target: "name ##{@target.id}",
      summary: @summary,
      content: @content
    }
    assert_api_fail(params.except(:api_key))
    assert_api_fail(params.except(:target))
    assert_api_fail(params.except(:summary))
    assert_api_fail(params.merge(target: "foo #1"))
    assert_api_fail(params.merge(target: "observation #1"))
    assert_api_pass(params)
    assert_last_comment_correct
  end

  def test_patching_comments
    com1 = comments(:minimal_unknown_obs_comment_1) # rolf's comment
    com2 = comments(:minimal_unknown_obs_comment_2) # dick's comment
    params = {
      method: :patch,
      action: :comment,
      api_key: @api_key.key,
      id: com1.id,
      set_summary: "new summary",
      set_content: "new comment"
    }
    assert_api_fail(params.except(:api_key))
    assert_api_fail(params.merge(id: com2.id))
    assert_api_fail(params.merge(set_summary: ""))
    assert_api_pass(params)
    com1.reload
    assert_equal("new summary", com1.reload.summary)
    assert_equal("new comment", com1.reload.comment)
  end

  def test_deleting_comments
    com1 = comments(:minimal_unknown_obs_comment_1) # rolf's comment
    com2 = comments(:minimal_unknown_obs_comment_2) # dick's comment
    params = {
      method: :delete,
      action: :comment,
      api_key: @api_key.key,
      id: com1.id
    }
    assert_api_fail(params.except(:api_key))
    assert_api_fail(params.merge(id: com2.id))
    assert_api_pass(params)
    assert_nil(Comment.safe_find(com1.id))
  end
end

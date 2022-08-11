# frozen_string_literal: true

require("test_helper")

class CommentControllerTest < FunctionalTestCase
  def test_list_comments
    login
    get_with_dump(:list_comments)
    assert_template("list_comments")
  end

  def test_show_comment
    login
    get_with_dump(:show_comment,
                  id: comments(:minimal_unknown_obs_comment_1).id)
    assert_template("show_comment")
  end

  def test_show_comments_for_user
    login
    get_with_dump(:show_comments_for_user, id: rolf.id)
    assert_template("list_comments")
  end

  def test_show_comments_by_user
    login
    get_with_dump(:show_comments_by_user, id: rolf.id)
    assert_redirected_to(action: "show_comment",
                         id: comments(:minimal_unknown_obs_comment_1).id,
                         params: @controller.query_params(QueryRecord.last))
  end

  def test_show_comments_for_target_with_comments
    target = observations(:minimal_unknown_obs)
    params = { type: target.class.name, id: target.id }
    comments = Comment.where(target_type: target.class.name, target: target)

    login
    get(:show_comments_for_target, params: params)
    assert_select("div[class *='list-group comment']", count: comments.size)
  end

  def test_show_comments_for_valid_target_without_comments
    target = names(:conocybe_filaris)
    params = { type: target.class.name, id: target.id }

    login
    get(:show_comments_for_target, params: params)
    assert_flash_text(:runtime_no_matches.l(types: "comments"))
  end

  def test_show_comments_for_invalid_target_type
    target = api_keys(:rolfs_api_key)
    params = { type: target.class.name, id: target.id }

    login
    get(:show_comments_for_target, params: params)
    assert_flash_text(:runtime_invalid.t(type: '"type"',
                                         value: params[:type].to_s))
  end

  def test_show_comments_for_non_model
    params = { type: "Hacker", id: 666 }

    login
    get(:show_comments_for_target, params: params)
    assert_flash_text(:runtime_invalid.t(type: '"type"',
                                         value: params[:type].to_s))
  end

  def test_add_comment
    obs_id = observations(:minimal_unknown_obs).id
    requires_login(:add_comment, id: obs_id, type: "Observation")
    assert_form_action(action: "add_comment", id: obs_id, type: "Observation")
  end

  def test_add_comment_no_id
    login("dick")
    get(:add_comment)
    assert_response(:redirect)
  end

  def test_add_comment_to_name_with_synonyms
    name_id = names(:chlorophyllum_rachodes).id
    requires_login(:add_comment, id: name_id, type: "Name")
    assert_form_action(action: "add_comment", id: name_id, type: "Name")
  end

  def test_add_comment_to_unreadable_object
    katrina_is_not_reader = name_descriptions(:peltigera_user_desc)
    login(:katrina)
    get(:add_comment,
        params: { type: "NameDescription", id: katrina_is_not_reader.id })

    assert_flash_error("MO should flash if trying to comment on object" \
                       "for which user lacks read privileges")
  end

  def test_edit_comment
    comment = comments(:minimal_unknown_obs_comment_1)
    obs = comment.target
    params = { id: comment.id.to_s }
    assert_equal("rolf", comment.user.login)
    requires_user(
      :edit_comment,
      { controller: :observations, action: :show, id: obs.id },
      params
    )
    assert_form_action(action: "edit_comment", id: comment.id.to_s)
  end

  def test_destroy_comment
    comment = comments(:minimal_unknown_obs_comment_1)
    obs = comment.target
    assert(obs.comments.member?(comment))
    assert_equal("rolf", comment.user.login)
    params = { id: comment.id.to_s }
    requires_user(
      :destroy_comment,
      { controller: :observations, action: :show, id: obs.id },
      params
    )
    assert_equal(9, rolf.reload.contribution)
    obs.reload
    assert_not(obs.comments.member?(comment))
  end

  def test_save_comment
    assert_equal(10, rolf.contribution)
    obs = observations(:minimal_unknown_obs)
    comment_count = obs.comments.size
    params = { id: obs.id,
               type: "Observation",
               comment: { summary: "A Summary", comment: "Some text." } }
    post_requires_login(:add_comment, params)
    assert_redirected_to(controller: :observations, action: :show)
    assert_equal(11, rolf.reload.contribution)
    obs.reload
    assert_equal(comment_count + 1, obs.comments.size)
    comment = Comment.last
    assert_equal("A Summary", comment.summary)
    assert_equal("Some text.", comment.comment)
  end

  def test_update_comment
    comment = comments(:minimal_unknown_obs_comment_1)
    obs = comment.target
    params = { id: comment.id,
               comment: { summary: "New Summary", comment: "New text." } }
    assert_equal("rolf", comment.user.login)
    post_requires_user(
      :edit_comment,
      { controller: :observations, action: :show, id: obs.id },
      params
    )
    assert_equal(10, rolf.reload.contribution)
    comment = Comment.find(comment.id)
    assert_equal("New Summary", comment.summary)
    assert_equal("New text.", comment.comment)
  end
end

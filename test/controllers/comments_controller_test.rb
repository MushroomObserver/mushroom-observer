# frozen_string_literal: true

require("test_helper")

class CommentsControllerTest < FunctionalTestCase
  def test_list_comments
    login
    get(:index)
    assert_template("index")
  end

  def test_index_by
    by = "user"

    login
    get(:index, params: { by: by })

    assert_select("#title").text.downcase == "comments by #{by}"
  end

  def test_index_pattern_id
    id = comments(:fungi_comment).id

    login
    get(:index, params: { pattern: id })

    assert_redirected_to(comment_path(id))
  end

  def test_index_pattern_search_str
    search_str = "Let's"
    assert(comments(:minimal_unknown_obs_comment_2).summary.
           start_with?(search_str),
           "Search string must have a hit in Comment fixtures")

    login
    get(:index, params: { pattern: search_str })

    assert_select("#title").text.downcase == "comments matching '#{search_str}'"
  end

  def test_show_comment
    login
    get(:show,
        params: { id: comments(:minimal_unknown_obs_comment_1).id })
    assert_template("show")
  end

  def test_show_comments_for_user
    login
    get(:index, params: { for_user: rolf.id })
    assert_template("index")
  end

  def test_show_comments_by_user
    login
    get(:index, params: { by_user: rolf.id })
    assert_redirected_to(action: "show",
                         id: comments(:minimal_unknown_obs_comment_1).id,
                         params: @controller.query_params(QueryRecord.last))
  end

  def test_show_comments_for_target_with_comments
    target = observations(:minimal_unknown_obs)
    params = { type: target.class.name, target: target.id }
    comments = Comment.where(target_type: target.class.name, target: target)

    login
    get(:index, params: params)
    assert_select("div[class *='list-group comment']", count: comments.size)
  end

  def test_show_comments_for_valid_target_without_comments
    target = names(:conocybe_filaris)
    params = { type: target.class.name, target: target.id }

    login
    get(:index, params: params)
    assert_flash_text(:runtime_no_matches.l(types: "comments"))
  end

  def test_show_comments_for_invalid_target_type
    target = api_keys(:rolfs_api_key)
    params = { type: target.class.name, target: target.id }

    login
    get(:index, params: params)
    assert_flash_text(:runtime_invalid.t(type: '"type"',
                                         value: params[:type].to_s))
  end

  def test_show_comments_for_non_model
    params = { type: "Hacker", target: 666 }

    login
    get(:index, params: params)
    assert_flash_text(:runtime_invalid.t(type: '"type"',
                                         value: params[:type].to_s))
  end

  def test_add_comment
    obs_id = observations(:minimal_unknown_obs).id
    requires_login(:new, target: obs_id, type: "Observation")
    assert_form_action(action: :create, target: obs_id, type: "Observation")
  end

  def test_add_comment_no_id
    login("dick")
    get(:new)
    assert_response(:redirect)
  end

  def test_add_comment_to_name_with_synonyms
    name_id = names(:chlorophyllum_rachodes).id
    requires_login(:new, target: name_id, type: "Name")
    assert_form_action(action: :create, target: name_id, type: "Name")
  end

  def test_add_comment_to_unreadable_object
    katrina_is_not_reader = name_descriptions(:peltigera_user_desc)
    login(:katrina)
    get(:new,
        params: { type: "NameDescription", target: katrina_is_not_reader.id })

    assert_flash_error("MO should flash if trying to comment on object" \
                       "for which user lacks read privileges")
  end

  def test_edit_comment
    comment = comments(:minimal_unknown_obs_comment_1)
    obs = comment.target
    params = { id: comment.id.to_s }
    assert_equal("rolf", comment.user.login)
    requires_user(:edit,
                  [{ controller: "/observations", action: :show,
                     id: obs.id }], params)
    assert_form_action(action: :update, id: comment.id.to_s)
  end

  def test_destroy_comment
    comment = comments(:minimal_unknown_obs_comment_1)
    obs = comment.target
    assert(obs.comments.member?(comment))
    assert_equal("rolf", comment.user.login)
    params = { id: comment.id.to_s }
    requires_user(:destroy,
                  [{ controller: "/observations", action: :show,
                     id: obs.id }], params)
    assert_equal(9, rolf.reload.contribution)
    obs.reload
    assert_not(obs.comments.member?(comment))
  end

  def test_save_comment
    assert_equal(10, rolf.contribution)
    obs = observations(:minimal_unknown_obs)
    comment_count = obs.comments.size
    params = { target: obs.id,
               type: "Observation",
               comment: { summary: "A Summary", comment: "Some text." } }
    post_requires_login(:create, params)
    assert_redirected_to(permanent_observation_path(obs.id))
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
    put_requires_user(:update,
                      [{ controller: "/observations",
                         action: :show, id: obs.id }], params)
    assert_equal(10, rolf.reload.contribution)
    comment = Comment.find(comment.id)
    assert_equal("New Summary", comment.summary)
    assert_equal("New text.", comment.comment)
  end
end

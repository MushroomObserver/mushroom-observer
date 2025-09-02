# frozen_string_literal: true

require("test_helper")

class CommentsControllerTest < FunctionalTestCase
  # Test of index, with tests arranged as follows:
  # default subaction; then
  # other subactions in order of index_active_params
  def test_index
    login
    get(:index)
    assert_template("index")
  end

  def test_index_by_non_default_sort_order
    by = "user"

    login
    get(:index, params: { by: by })

    assert_page_title(:COMMENTS.l)
    assert_sorted_by(by)
  end

  def test_index_target_has_comments
    target = observations(:minimal_unknown_obs)
    params = { type: target.class.name, target: target.id }
    comments = Comment.where(target_type: target.class.name, target: target)

    login
    get(:index, params: params)
    assert_select(".comment", count: comments.size)
    assert_page_title(:COMMENTS.l)
    assert_displayed_filters("#{:query_target.l}: #{target.unique_text_name.t}")
  end

  def test_index_target_valid_target_without_comments
    target = names(:conocybe_filaris)
    params = { type: target.class.name, target: target.id }

    login
    get(:index, params: params)
    assert_flash_text(:runtime_no_matches.l(types: "comments"))
  end

  def test_index_target_invalid_target_type
    target = api_keys(:rolfs_api_key)
    params = { type: target.class.name, target: target.id }

    login
    get(:index, params: params)
    assert_flash_text(:runtime_invalid.t(type: '"type"',
                                         value: params[:type].to_s))
  end

  def test_index_target_for_non_model
    params = { type: "Hacker", target: 666 }

    login
    get(:index, params: params)
    assert_flash_text(:runtime_invalid.t(type: '"type"',
                                         value: params[:type].to_s))
  end

  def test_index_pattern_search_str
    search_str = "Let's"
    assert(comments(:minimal_unknown_obs_comment_2).summary.
           start_with?(search_str),
           "Search string must have a hit in Comment fixtures")

    login
    get(:index, params: { pattern: search_str })

    assert_page_title(:COMMENTS.l)
    assert_displayed_filters("#{:query_pattern.l}: #{search_str}")
  end

  def test_index_by_user_who_created_one_comment
    user = rolf
    assert_equal(1, Comment.where(user: user).count)

    login
    get(:index, params: { by_user: rolf.id })

    assert_redirected_to(
      action: "show",
      id: comments(:minimal_unknown_obs_comment_1).id
    )
  end

  def test_index_by_user_who_created_multiple_comments
    user = rolf
    another_comment_by_user = comments(:detailed_unknown_obs_comment)
    another_comment_by_user.user = user
    another_comment_by_user.save
    assert(Comment.where(user: user).many?)

    login
    get(:index, params: { by_user: user.id })

    assert_page_title(:COMMENTS.l)
    assert_displayed_filters("#{:query_by_users.l}: #{user.name}")
    # All Rolf's Comments are Observations, so the results should have
    # as many links to Observations as Rolf has Comments
    assert_select(
      "#results a:match('href', ?)", %r{^/obs/\d+}, # match obs links
      { count: Comment.where(user: user).count },
      "Wrong number of links to Observations in results"
    )
    assert_session_query_record_is_correct
  end

  def test_index_by_user_who_created_no_comments
    user = users(:zero_user)

    login
    get(:index, params: { by_user: user.id })

    assert_flash_text(:runtime_no_matches.l(types: "comments"))
  end

  def test_index_by_user_nonexistent_user
    id = observations(:minimal_unknown_obs).id

    login
    get(:index, params: { by_user: id })

    assert_flash_text(:runtime_object_not_found.l(type: :user, id: id))
    assert_redirected_to(comments_path)
  end

  def test_index_for_user_who_received_multiple_comments
    user = mary

    login
    get(:index, params: { for_user: user.id })

    assert_template("index")
    assert_page_title(:COMMENTS.l)
    assert_displayed_filters("#{:query_for_user.l}: #{user.name}")
    assert_session_query_record_is_correct
  end

  def test_index_for_user_who_received_one_comment
    user = dick
    # Change comment to be on one of Dick's Observations
    comment = comments(:minimal_unknown_obs_comment_1)
    target = observations(:owner_refuses_general_questions)
    comment.target_id = target.id
    comment.save

    login
    get(:index, params: { for_user: user.id })

    assert_match(comment_path(comment), redirect_to_url)
    assert_session_query_record_is_correct
  end

  def test_index_for_user_who_received_no_comments
    user = users(:zero_user)

    login
    get(:index, params: { for_user: user.id })

    assert_flash_text(:runtime_no_matches.l(types: "comments"))
  end

  def test_index_for_user_nonexistent_user
    id = observations(:minimal_unknown_obs).id

    login
    get(:index, params: { for_user: id })

    assert_flash_text(:runtime_object_not_found.l(type: :user, id: id))
    assert_redirected_to(comments_path)
  end

  #########################################################

  def test_show_comment
    login
    get(:show,
        params: { id: comments(:minimal_unknown_obs_comment_1).id })
    assert_template("show")
  end

  def test_new_comment
    obs_id = observations(:minimal_unknown_obs).id
    requires_login(:new, target: obs_id, type: :Observation)
    assert_form_action(action: :create, target: obs_id, type: :Observation)
  end

  def test_new_comment_turbo
    obs_id = observations(:minimal_unknown_obs).id
    login
    get(:new, params: { target: obs_id, type: :Observation },
              format: :turbo_stream)
    assert_template("shared/_modal_form")
    assert_template("comments/_form")
    assert_form_action(action: :create, target: obs_id, type: :Observation)
  end

  def test_new_comment_for_project
    project_id = projects(:eol_project).id
    requires_login(:new, target: project_id, type: :Project)
    assert_form_action(action: :create, target: project_id, type: :Project)
  end

  def test_new_comment_no_id
    login("dick")
    get(:new)
    assert_response(:redirect)
  end

  def test_new_comment_for_name_with_synonyms
    name_id = names(:chlorophyllum_rachodes).id
    requires_login(:new, target: name_id, type: :Name)
    assert_form_action(action: :create, target: name_id, type: :Name)
  end

  def test_new_comment_to_unreadable_object
    katrina_is_not_reader = name_descriptions(:peltigera_user_desc)
    params = { type: :NameDescription, target: katrina_is_not_reader.id }
    login(:katrina)

    get(:new, params:)
    assert_flash_error("MO should flash if trying to comment on object" \
                       "for which user lacks read privileges")

    # Test turbo shows flash error
    get(:new, params:, format: :turbo_stream)
    assert_template("shared/_modal_flash_update")
    assert_flash_error
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

  def test_edit_comment_turbo
    comment = comments(:minimal_unknown_obs_comment_1)
    login

    get(:edit, params: { id: comment.id }, format: :turbo_stream)
    assert_template("shared/_modal_form")
    assert_template("comments/_form")
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

  def test_create_comment
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

  def test_comment_broadcast
    obs = observations(:minimal_unknown_obs)
    comment_count = obs.comments.size
    params = { target: obs.id,
               type: "Observation",
               comment: { summary: "A Summary", comment: "Some text." } }
    login
    assert_turbo_stream_broadcasts([obs, :comments], count: 1) do
      post(:create, params:)
    end
    obs.reload
    assert_equal(comment_count + 1, obs.comments.size)
  end
end

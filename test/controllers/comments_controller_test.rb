# frozen_string_literal: true

require("test_helper")

class CommentsControllerTest < FunctionalTestCase
  # Test of index, with tests arranged as follows:
  # default subaction; then
  # other subactions in order of index_active_params
  def test_index
    login
    get(:index)
    assert_response(:success)
    assert_select("body.comments__index")
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
    pattern = "Let's"
    assert(comments(:minimal_unknown_obs_comment_2).summary.
           start_with?(pattern),
           "Search string must have a hit in Comment fixtures")

    login
    get(:index, params: { q: { model: :Comment, pattern: } })

    assert_page_title(:COMMENTS.l)
    assert_displayed_filters("#{:query_pattern.l}: #{pattern}")
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

    assert_response(:success)
    assert_select("body.comments__index")
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
    comment = comments(:minimal_unknown_obs_comment_1)
    login
    get(:show, params: { id: comment.id })
    assert_response(:success)
    assert_select("body.comments__show")
  end

  def test_show_comment_flow_next_and_prev_redirect
    comment = comments(:minimal_unknown_obs_comment_1)
    login
    get(:show, params: { id: comment.id, flow: "next" })
    assert_response(:redirect)
    get(:show, params: { id: comment.id, flow: "prev" })
    assert_response(:redirect)
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
    # Assert CommentForm component rendered
    assert_select("form#comment_form")
    assert_select("input[name='comment[summary]']")
    assert_select("textarea[name='comment[comment]']")
    assert_form_action(action: :create, target: obs_id, type: :Observation)
  end

  def test_new_comment_for_project
    project_id = projects(:eol_project).id
    requires_login(:new, target: project_id, type: :Project)
    assert_form_action(action: :create, target: project_id, type: :Project)
  end

  # The modal title (built via `viewer_aware_unique_format_name`)
  # passes the viewer straight through to `unique_format_name`.
  def test_new_comment_for_project_turbo
    project = projects(:eol_project)
    login
    get(:new, params: { target: project.id, type: :Project },
              format: :turbo_stream)

    assert_select(
      "h4.modal-title#modal_comment_header",
      text: /#{Regexp.escape(project.unique_format_name)}/
    )
  end

  # `CommentsController#modal_title`'s call to
  # `viewer_aware_unique_format_name(@target)` passes the viewer
  # straight through to `unique_format_name`.
  def test_new_comment_for_location_turbo
    location = locations(:albion)
    login
    get(:new, params: { target: location.id, type: :Location },
              format: :turbo_stream)

    assert_select("form#comment_form")
    assert_form_action(action: :create, target: location.id, type: :Location)
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
    assert_select("turbo-stream[action='update'][target$='_flash']")
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
    assert_select("#modal_comment_#{comment.id}")
    assert_select("form#comment_form")
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

  # `destroy`'s `!@comment.destroy` branch
  # (`flash_error(:runtime_form_comments_destroy_failed)`). Stub
  # `Comment#destroy` to return false on the controller-found
  # instance, matching the pattern in
  # `projects_controller_test.rb#test_project_destroy_fail` and
  # `glossary_terms_controller_test.rb#test_destroy_glossary_term_fails`.
  # `find_or_goto_index` uses `Comment.show_includes.find_by`, and the
  # destroy path re-fetches nothing further — stub both so the
  # controller sees our destroy-mocked instance.
  def test_destroy_comment_fails
    comment = comments(:minimal_unknown_obs_comment_1)
    login("rolf")

    comment.stub(:destroy, false) do
      Comment.stub(:show_includes, Comment) do
        Comment.stub(:find_by, comment) do
          delete(:destroy, params: { id: comment.id })
        end
      end
    end

    assert_flash_error
  end

  def test_update_comment_with_no_changes
    # `comment_updated?` `!@comment.changed?` branch: notice + false.
    comment = comments(:minimal_unknown_obs_comment_1)
    params = { id: comment.id,
               comment: { summary: comment.summary,
                          comment: comment.comment } }
    login("rolf")
    put(:update, params: params)
    assert_flash_text(:runtime_no_changes.t)
  end

  def test_update_comment_with_invalid_params_re_renders_form
    # `comment_updated?` `!@comment.save` branch + reload_form
    # HTML path.
    comment = comments(:minimal_unknown_obs_comment_1)
    params = { id: comment.id,
               comment: { summary: "", comment: "Body" } }
    login("rolf")
    put(:update, params: params)
    assert_response(:success)
    assert_select("form#comment_form")
  end

  def test_create_comment_turbo_invalid_reloads_modal_form
    # `reload_form` turbo_stream branch → `reload_modal_form`.
    obs = observations(:minimal_unknown_obs)
    params = { target: obs.id, type: "Observation",
               comment: { summary: "", comment: "Body" } }
    login
    post(:create, params: params, format: :turbo_stream)
    assert_response(:success)
  end

  def test_create_comment_with_invalid_params_re_renders_form
    # `reload_form` HTML branch: missing summary fails save and
    # falls through to `render_phlex_new`.
    obs = observations(:minimal_unknown_obs)
    params = { target: obs.id, type: "Observation",
               comment: { summary: "", comment: "Body" } }
    login
    post(:create, params: params)
    assert_response(:success)
    assert_select("body.comments__new")
    assert_select("form#comment_form")
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
    comment = Comment.find_by(summary: "A Summary", target: obs)
    assert_not_nil(comment, "Cannot find Comment")
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

  def test_create_comment_turbo_stream_removes_modal
    obs = observations(:minimal_unknown_obs)
    params = { target: obs.id,
               type: "Observation",
               comment: { summary: "Turbo Test",
                          comment: "Some text." } }
    login
    post(:create, params: params, as: :turbo_stream)
    assert_response(:success)
    # close_modal triggers Bootstrap cleanup (backdrop + body class);
    # remove drops the element so the next open fetches a fresh form.
    assert_select("turbo-stream[action='close_modal']", text: "modal_comment")
    assert_select("turbo-stream[action=?][target=?]", "remove", "modal_comment")
  end

  # The synchronous response has to insert the new row itself -- the
  # `Comment` model's own `after_create_commit` broadcast is async
  # and isn't guaranteed to reach the submitter's own tab before (or
  # ever, if the connection drops) the modal closes (#4833). It uses
  # the custom `prepend_once` action, not the built-in `prepend`:
  # `after_create_commit` dispatches its own broadcast before this
  # response is even built, so a plain `prepend` here would routinely
  # race a duplicate insert of the same row. `prepend_once` is a
  # client-side no-op if the row's id is already in the DOM (see
  # `config/initializers/turbo_stream_actions.rb`), so whichever of
  # the two arrives second doesn't duplicate it.
  def test_create_comment_turbo_stream_prepends_row_once
    obs = observations(:minimal_unknown_obs)
    params = { target: obs.id,
               type: "Observation",
               comment: { summary: "Turbo Prepend Test",
                          comment: "Some text." } }
    login
    post(:create, params: params, as: :turbo_stream)
    assert_response(:success)
    comment = Comment.find_by(summary: "Turbo Prepend Test", target: obs)
    assert_not_nil(comment, "Cannot find Comment")

    assert_select(
      "turbo-stream[action=?][target=?] " \
      ".comment##{ActionView::RecordIdentifier.dom_id(comment)}",
      "prepend_once", "comments"
    )
    assert_select(
      "turbo-stream[action=?][target=?] .comment-summary",
      "prepend_once", "comments", text: comment.summary
    )
    # Guard against reverting to the plain (non-deduping) action.
    assert_select("turbo-stream[action=?][target=?]", "prepend", "comments",
                  count: 0)
  end

  def test_update_comment_turbo_stream_removes_scoped_modal
    comment = comments(:minimal_unknown_obs_comment_1)
    login_for(comment)
    params = { id: comment.id,
               comment: { summary: "Updated Summary",
                          comment: "Updated body." } }
    put(:update, params: params, as: :turbo_stream)
    assert_response(:success)
    target_id = "modal_comment_#{comment.id}"
    assert_select("turbo-stream[action='close_modal']", text: target_id)
    assert_select("turbo-stream[action=?][target=?]", "remove", target_id)
  end

  # The synchronous response has to update the row itself -- the
  # `Comment` model's own `after_update_commit` broadcast is async
  # and isn't guaranteed to reach the submitter's own tab before (or
  # ever, if the connection drops) the modal closes (#4833).
  def test_update_comment_turbo_stream_updates_row
    comment = comments(:minimal_unknown_obs_comment_1)
    login_for(comment)
    params = { id: comment.id,
               comment: { summary: "Updated Summary",
                          comment: "Updated body." } }
    put(:update, params: params, as: :turbo_stream)
    assert_response(:success)

    assert_select(
      "turbo-stream[action=?][target=?] .comment-summary",
      "update", ActionView::RecordIdentifier.dom_id(comment),
      text: "Updated Summary"
    )
    assert_select(
      "turbo-stream[action=?][target=?] .comment-body",
      "update", ActionView::RecordIdentifier.dom_id(comment),
      text: "Updated body."
    )
  end

  # The synchronous response has to remove the row itself -- the
  # `Comment` model's own `after_destroy_commit` broadcast is async
  # and isn't guaranteed to reach the submitter's own tab before (or
  # ever, if the connection drops) the modal closes (#4833).
  def test_destroy_comment_turbo_stream_removes_row
    comment = comments(:minimal_unknown_obs_comment_1)
    login_for(comment)

    delete(:destroy, params: { id: comment.id }, as: :turbo_stream)
    assert_response(:success)

    assert_select("turbo-stream[action=?][target=?]", "remove",
                  ActionView::RecordIdentifier.dom_id(comment))
  end

  def login_for(comment)
    login(User.find(comment.user_id).login)
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

  # The `after_create_commit` broadcast renders `_comment.erb`
  # without a request context — `@user` is nil. The mod-links
  # span (`[ edit | destroy ]`) still has to be in the broadcast
  # markup so the comment's author can interact with their just-
  # created comment; client-side CSS (`[data-user-specific]:not(…)`)
  # hides it for everyone else.
  def test_comment_broadcast_includes_mod_links_for_author
    obs = observations(:minimal_unknown_obs)
    login("rolf")
    payloads = capture_turbo_stream_broadcasts([obs, :comments]) do
      post(:create, params: {
             target: obs.id, type: "Observation",
             comment: { summary: "Mod-links test",
                        comment: "Body" }
           })
    end
    comment = ::Comment.find_by(summary: "Mod-links test")
    assert_not_nil(comment, "Comment didn't save")

    # `capture_turbo_stream_broadcasts` returns
    # `Nokogiri::XML::Element` nodes (the `<turbo-stream>` wrappers).
    # `prepend_once`, not the built-in `prepend` -- see
    # `CommentsController::RowStreams` for why the plain action would
    # risk duplicating the row the controller may have already
    # inserted synchronously.
    assert_equal("prepend_once", payloads.last["action"],
                 "Comment create broadcast should use the deduping " \
                 "prepend_once action")
    html = payloads.last.to_html
    # The mod-links span carries `data-user-specific` keyed to
    # the comment's author id — that's the CSS's selector hook.
    assert_match(/data-user-specific="#{comment.user.id}"/, html)
    # `Components::Link::InlineMod` emits a `<form>` with the
    # delete-method input for destroy, and the edit modal anchor
    # with `data-modal="modal_comment_<id>"`. Pin both as the
    # contract.
    assert_match(/data-modal="modal_comment_#{comment.id}"/, html)
    assert_match(/<input[^>]*name="_method"[^>]*value="delete"/, html)
  end

  # Companion: in a regular page-render context (not a broadcast),
  # `@user` is set. `InlineModLinks` gates server-side on
  # owner-or-admin — the mod-links HTML doesn't appear at all
  # for non-authors. The `data-user-specific` CSS would have
  # hidden them anyway, but defense in depth is better when the
  # logic is cheap (one `==` comparison) — and a non-author
  # snooping the page source no longer sees affordances they
  # can't actually use.
  def test_comments_page_omits_mod_links_for_non_author
    obs = observations(:detailed_unknown_obs)
    comment = obs.comments.find { |c| c.user != users(:rolf) } ||
              skip("Need a comment authored by a user other than rolf")
    login("rolf")

    get(:show, params: { id: comment.id })
    assert_response(:success)

    # The mod-links span has `data-user-specific` keyed to the
    # COMMENT AUTHOR's id (not rolf). Rolf isn't the author, so
    # the InlineModLinks render should produce no edit/destroy
    # affordances at all — neither the modal-link edit anchor
    # nor the destroy form.
    assert_select(
      "a[data-modal='modal_comment_#{comment.id}']", count: 0
    )
    assert_select(
      "form[action='/comments/#{comment.id}'] " \
      "input[name='_method'][value='delete']", count: 0
    )
  end
end

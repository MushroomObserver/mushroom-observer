# frozen_string_literal: true

require("test_helper")

class ImagesControllerTest < FunctionalTestCase
  # Tests of index, with tests arranged as follows:
  # default subaction; then
  # other subactions in order of index_active_params
  def test_index_order
    check_index_sorted_by(::Query::Images.default_order) # :created_at
    assert_select(".matrix-box")
    assert_page_title(:images.ti)
  end

  # Sorting by `name` or `user` flips `opts[:letters] = true` in
  # `ImagesController#index_display_opts`, switching the index to
  # letter-based pagination.
  def test_index_sort_by_name_enables_letter_pagination
    login
    get(:index, params: { by: "name" })

    assert_response(:success)
  end

  # Companion to the `name` case above -- exercises
  # `Query::Images#alphabetical_by`'s `"user"`/`"reverse_user"` branch
  # (`User[:login]`), not just `"name"`/`"reverse_name"`.
  def test_index_sort_by_user_enables_letter_pagination
    login
    get(:index, params: { by: "user" })

    assert_response(:success)
  end

  def test_index_by_user
    user = rolf

    login
    get(:index, params: { by_user: user.id })

    assert_select("body.images__index")
    assert_select(".matrix-box")
    assert_page_title(:images.ti)
    assert_displayed_filters("#{:query_by_users.l}: #{user.legal_name}")
  end

  def test_index_by_user_single_match_redirects
    user = katrina
    image = Image.where(user: user).first
    assert(Image.where(user: user).one?)

    login
    get(:index, params: { by_user: user.id })

    assert_redirected_to(image_path(image.id))
  end

  def test_index_by_users_bad_user_id
    bad_user_id = observations(:minimal_unknown_obs).id
    assert_empty(User.where(id: bad_user_id), "Test needs different 'bad_id'")

    login
    get(:index, params: { by_user: bad_user_id })

    assert_flash(:runtime_object_not_found, type: :user, id: bad_user_id)
    assert_redirected_to(images_path)
  end

  def test_index_projects
    project = projects(:bolete_project)
    login
    get(:index, params: { project: project.id })

    assert_select(".matrix-box")
    assert_page_title(:images.ti)
    assert_displayed_filters("#{:query_projects.l}: #{project.title}")
  end

  def test_index_project_single_match_redirects
    project = projects(:lone_wolf_project)
    image = Image.projects(project.id).first
    assert(Image.projects(project.id).one?)

    login
    get(:index, params: { project: project.id })

    assert_redirected_to(image_path(image.id))
  end

  def test_index_too_many_pages
    login
    get(:index, params: { page: 1_000_000 })

    # 429 == :too_many_requests. The symbolic response code does not work.
    # Perhaps we're not loading that part of Rack. JDC 2022-08-17
    assert_response(429) # rubocop:disable Rails/HttpStatus
  end

  # The pattern param is maintained only for backwards compatibility.
  # Should redirect to SearchController#pattern
  def test_index_pattern_param_redirected_to_search
    pattern = "USA"

    login
    get(:index, params: { pattern: pattern })
    assert_redirected_to(
      search_pattern_path(pattern_search: { pattern:, type: :images })
    )
  end

  def q_pattern(pattern)
    { q: { model: :Image, pattern: } }
  end

  def test_index_pattern_text_multiple_hits
    pattern = "USA"
    params = q_pattern(pattern)

    login
    get(:index, params:)

    assert_select(".matrix-box")
    assert_page_title(:images.ti)
    assert_displayed_filters("#{:query_pattern.l}: #{pattern}")
  end

  def test_index_pattern_text_no_hits
    pattern = "nothingMatchesAxotl"
    params = q_pattern(pattern)

    login
    get(:index, params:)

    assert_flash(:runtime_no_matches, type: :image)
    assert_select("body.images__index")
  end

  # Regression for #4360: a cross-model q param (Observation query
  # landing on the Images index) used to silently fall back to the
  # full unfiltered Image index — a >60s response that could trigger
  # downtime alerts. The query-coercion bridge in
  # `find_new_query_for_model` should map the Observation query to an
  # Image query via the `observation_query` subquery instead.
  def test_index_cross_model_q_param_with_hits
    pattern = "USA"
    params = { q: { model: :Observation, pattern: } }

    login
    get(:index, params:)

    assert_select(".matrix-box")
    # Should NOT have flashed "no matches" — the bridge produces hits.
    assert_no_flash
  end

  def test_index_cross_model_q_param_no_hits_flashes_error
    pattern = "nothingMatchesAxotl"
    params = { q: { model: :Observation, pattern: } }

    login
    get(:index, params:)

    # Zero matching Observations → zero matching Images → "no matches"
    # flash, not a silent fall-back to the unfiltered Image index.
    assert_flash(:runtime_no_matches, type: :image)
    assert_select("body.images__index")
  end

  def test_show_image
    image = images(:peltigera_image)
    assert(ImageVote.where(image: image).many?,
           "Use Image fixture with multiple votes for better coverage")
    num_views = image.num_views
    login
    get(:show, params: { id: image.id })
    assert_select("body.images__show")
    image.reload
    assert_equal(num_views + 1, image.num_views)
    (Image::ALL_SIZES + [:original]).each do |size|
      get(:show, params: { id: image.id, size: size })
      assert_select("body.images__show")
    end
  end

  # The Read Field Slip button is offered on every image with an
  # observation -- a plausibility test that guessed wrong would hide it
  # on exactly the slips someone wants to read -- but only to people
  # who may press it (FieldSlipExtract.permitted?).
  def test_show_hides_field_slip_button_from_ordinary_users
    image = images(:in_situ_image)
    login("katrina")

    get(:show, params: { id: image.id })

    assert_select("form[action=?]",
                  image_field_slip_extract_path(image.id), count: 0)
  end

  def test_show_offers_field_slip_button_to_site_admin
    image = images(:in_situ_image)
    login("rolf")
    make_admin

    get(:show, params: { id: image.id })

    assert_select("form[action=?]", image_field_slip_extract_path(image.id))
  end

  def test_show_offers_field_slip_button_to_project_admin
    image = images(:in_situ_image)
    obs = image.observations.first
    project = projects(:eol_project)
    project.observations << obs unless project.observations.include?(obs)
    login(mary.login)

    assert(project.is_admin?(mary), "premise: mary administers it")
    get(:show, params: { id: image.id })

    assert_select("form[action=?]", image_field_slip_extract_path(image.id))
    assert_select("a[href=?]", edit_image_field_slip_extract_path(image.id),
                  count: 0)
  end

  # The Read button always re-reads; an existing read is reachable from
  # here too, as a button labelled by its state, so a result that
  # landed unseen is not lost behind a re-read. Read doubles as the
  # retry for a failed one, so no separate Retry button here.
  def test_show_links_existing_field_slip_read
    image = images(:in_situ_image)
    login("rolf")
    make_admin
    FieldSlipExtract.fail!(image: image, user: rolf, error: "boom")

    get(:show, params: { id: image.id })

    assert_select("a.btn[href=?]",
                  edit_image_field_slip_extract_path(image.id),
                  text: :field_slip_scan_failed.l)
    assert_select("form[action=?] button.btn.ml-2",
                  image_field_slip_extract_path(image.id),
                  text: :field_slip_extract_button.l)
    assert_select("form[action=?] button",
                  image_field_slip_extract_path(image.id), count: 1)
  end

  def test_show_hides_existing_field_slip_read_from_ordinary_users
    image = images(:in_situ_image)
    FieldSlipExtract.start!(image: image, user: rolf)
    login("katrina")

    get(:show, params: { id: image.id })

    assert_select("a[href=?]", edit_image_field_slip_extract_path(image.id),
                  count: 0)
  end

  # #4989: rotate/mirror controls follow permission on the image itself
  # OR on the Observation it belongs to -- not just the image's own
  # (separate) project attachment.
  def test_show_hides_transform_buttons_from_unrelated_user
    image = images(:commercial_inquiry_image)
    login("katrina")

    get(:show, params: { id: image.id })

    assert_select(
      "form[action=?]",
      transform_image_path(id: image.id, op: "rotate_left",
                           size: katrina.image_size),
      count: 0
    )
  end

  def test_show_offers_transform_buttons_to_project_admin_of_observation
    image = images(:commercial_inquiry_image)
    obs = observations(:detailed_unknown_obs)
    image.observations << obs
    admin = dick
    assert(obs.can_edit?(admin), "premise: dick can edit this observation")

    login(admin.login)
    get(:show, params: { id: image.id })

    assert_select(
      "form[action=?]",
      transform_image_path(id: image.id, op: "rotate_left",
                           size: admin.image_size)
    )
  end

  def test_show_offers_transform_buttons_in_admin_mode
    image = images(:commercial_inquiry_image)
    admin = make_admin("katrina")

    get(:show, params: { id: image.id })

    assert_select(
      "form[action=?]",
      transform_image_path(id: image.id, op: "rotate_left",
                           size: admin.image_size)
    )
  end

  def test_show_image_info_panel_heading
    image = images(:peltigera_image)
    login
    get(:show, params: { id: image.id })
    assert_response(:success)

    # First check that the image panel heading is working
    assert_select("#image_panel .panel-heading") do |elements|
      assert_equal(1, elements.size, "Should find image panel heading")
      # Should contain the control links
      assert_match(/Show Original Image/, elements.first.text)
    end

    # Now check that the info panel heading "Notes:" is present
    assert_select("#info_panel .panel-heading") do |elements|
      assert_equal(1, elements.size, "Should find info panel heading")
      assert_match(/Notes:/, elements.first.text)
    end
  end

  def test_show_image_nil_user
    image = images(:peltigera_image)
    image.update(user: nil)

    login
    get(:show, params: { id: image.id })

    assert_response(:success)
    assert_select("body.images__show")
  end

  # Prove show works when params include obs
  def test_show_with_obs_param
    obs = observations(:peltigera_obs)
    assert(image = obs.images.first, "Test needs Obs fixture with images")

    login(obs.user.login)

    get(:show, params: { id: image.id, obs: obs.id })
    assert_select("body.images__show")
    # first_query = Query.find(QueryRecord.first.id)
    # second_query = Query.find(QueryRecord.second.id)
    # assert_equal(Observation, first_query.model)
    # assert_equal(Image, second_query.model)
  end

  def test_show_image_with_bad_vote
    image = images(:peltigera_image)
    assert(ImageVote.where(image: image).many?,
           "Use Image fixture with multiple votes for better coverage")
    # create invalid vote in order to cover line that rescues an error
    bad_vote = ImageVote.new(image: image, user: nil, value: Image.minimum_vote)
    bad_vote.save!(validate: false)
    num_views = image.num_views

    login
    get(:show, params: { id: image.id })

    assert_select("body.images__show")
    assert_equal(num_views + 1, image.reload.num_views)
    (Image::ALL_SIZES + [:original]).each do |size|
      get(:show, params: { id: image.id, size: size })
      assert_select("body.images__show")
    end
  end

  def test_show_image_change_user_default_size
    image = images(:in_situ_image)
    user = users(:rolf)
    assert_equal("medium", user.image_size, "Need different fixture for test")
    login(user.login)

    get(:show, params: { id: image.id, size: :small, make_default: "1" })
    assert_equal("small", user.reload.image_size)
  end

  def test_show_image_change_user_vote
    image = images(:peltigera_image)
    user = users(:rolf)
    changed_vote = Image.minimum_vote

    login(user.login)
    get(:show, params: { id: image.id, vote: changed_vote, next: true })

    assert_equal(changed_vote, image.reload.users_vote(user),
                 "Failed to change user's vote for image")
  end

  def test_next_image
    login
    get(:show, params: { id: images(:turned_over_image).id, flow: :next })
    # Default sort order is inverse chronological (created_at DESC, id DESC).
    # So here, "next" image is one created immediately previously.
    assert_redirected_to(%r{images/#{images(:in_situ_image).id}[\b|?]})
  end

  def test_prev_image
    login
    # oldest image
    get(:show, params: { id: images(:in_situ_image).id, flow: :prev })
    # so "prev" is the 2nd oldest
    assert_redirected_to(%r{images/#{images(:turned_over_image).id}[\b|?]})
  end

  def test_destroy_image
    image = images(:turned_over_image)
    obs = image.observations.first
    assert(obs.images.member?(image))
    params = { id: image.id }
    assert_equal("mary", image.user.login)
    delete_requires_user(:destroy, { action: :show, id: image.id }, params,
                         "mary")
    assert_redirected_to(action: :index)
    assert_equal(0, mary.reload.contribution)
    assert_not(obs.reload.images.member?(image))
  end

  # Prove that destroying image with query redirects to next image
  def test_destroy_image_with_query
    user = users(:mary)
    assert(user.images.size > 1, "Need different fixture for test")
    image = user.images.reorder(created_at: :asc).second
    next_image = user.images.reorder(created_at: :asc).first
    obs = image.observations.reorder(created_at: :asc).first
    assert(obs.images.member?(image))
    query = @controller.find_or_create_query(:Image, by_users: user)
    q = @controller.q_param(query)
    params = { id: image.id, q: }

    delete_requires_user(:destroy, { action: :show, id: image.id },
                         params, user.login)

    assert_redirected_to(action: :show, id: next_image.id)
    assert_session_query_record_is_correct
    assert_equal(0, user.reload.contribution)
    assert_not(obs.reload.images.member?(image))
  end

  def test_original_filename_visibility
    # Rolf's image, original name: "Name with áč€εиts.gif"
    img_id = images(:agaricus_campestris_image).id
    login("mary")

    rolf.keep_filenames = "toss"
    rolf.save
    get(:show, params: { id: img_id })
    assert_false(@response.body.include?("áč€εиts"))

    rolf.keep_filenames = "keep_but_hide"
    rolf.save
    get(:show, params: { id: img_id })
    assert_false(@response.body.include?("áč€εиts"))

    rolf.keep_filenames = "keep_and_show"
    rolf.save
    get(:show, params: { id: img_id })
    assert_true(@response.body.include?("áč€εиts"))

    login("rolf")

    rolf.keep_filenames = "toss"
    rolf.save
    get(:show, params: { id: img_id })
    assert_true(@response.body.include?("áč€εиts"))

    rolf.keep_filenames = "keep_but_hide"
    rolf.save
    get(:show, params: { id: img_id })
    assert_true(@response.body.include?("áč€εиts"))

    rolf.keep_filenames = "keep_and_show"
    rolf.save
    get(:show, params: { id: img_id })
    assert_true(@response.body.include?("áč€εиts"))
  end

  def test_show_user_profile_image
    assert(rolf.image_id)
    login
    get(:show, params: { id: rolf.image_id })
  end

  def test_show_glossary_term_image
    login
    conic = glossary_terms(:conic_glossary_term)
    assert(conic.thumb_image_id)
    get(:show, params: { id: conic.thumb_image_id })
  end

  def test_show_image_has_okay_link
    login
    image = images(:in_situ_image)
    image.update(diagnostic: false)
    get(:show, params: { id: image.id })
    assert_true(@response.body.include?("type=image&amp;value=1"))
  end
end

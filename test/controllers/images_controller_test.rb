# frozen_string_literal: true

require("test_helper")

class ImagesControllerTest < FunctionalTestCase
  # Tests of index, with tests arranged as follows:
  # default subaction; then
  # other subactions in order of index_active_params
  def test_index_order
    check_index_sorted_by(::Query::Images.default_order) # :created_at
    assert_template(partial: "_matrix_box")
    assert_page_title(:IMAGES.l)
  end

  def test_index_with_non_default_sort
    check_index_sorting
  end

  def test_index_by_user
    user = rolf

    login
    get(:index, params: { by_user: user.id })

    assert_template("index")
    assert_template(partial: "_matrix_box")
    assert_page_title(:IMAGES.l)
    assert_displayed_filters("#{:query_by_users.l}: #{user.legal_name}")
  end

  def test_index_by_users_bad_user_id
    bad_user_id = observations(:minimal_unknown_obs).id
    assert_empty(User.where(id: bad_user_id), "Test needs different 'bad_id'")

    login
    get(:index, params: { by_user: bad_user_id })

    assert_flash_text(
      :runtime_object_not_found.l(type: "user", id: bad_user_id)
    )
    assert_redirected_to(images_path)
  end

  def test_index_projects
    project = projects(:bolete_project)
    login
    get(:index, params: { project: project.id })

    assert_template("index", partial: "_image")
    assert_page_title(:IMAGES.l)
    assert_displayed_filters("#{:query_projects.l}: #{project.title}")
  end

  def test_index_too_many_pages
    login
    get(:index, params: { page: 1_000_000 })

    # 429 == :too_many_requests. The symbolic response code does not work.
    # Perhaps we're not loading that part of Rack. JDC 2022-08-17
    assert_response(429) # rubocop:disable Rails/HttpStatus
  end

  def test_index_advanced_search_error
    query_no_conditions = Query.lookup_and_save(:Image)

    login
    params = @controller.query_params(query_no_conditions).
             merge({ advanced_search: true })
    get(:index, params:)

    assert_flash_error(:runtime_no_conditions.l)
    assert_redirected_to(search_advanced_path)
  end

  def test_index_pattern_text_multiple_hits
    pattern = "USA"

    login
    get(:index, params: { pattern: pattern })

    assert_template("index", partial: "_image")
    assert_page_title(:IMAGES.l)
    assert_displayed_filters("#{:query_pattern.l}: #{pattern}")
  end

  def test_index_pattern_text_no_hits
    pattern = "nothingMatchesAxotl"

    login
    get(:index, params: { pattern: pattern })

    assert_flash_text(:runtime_no_matches.l(type: :images.l))
    assert_template("index")
  end

  def test_index_pattern_image_id
    image = images(:commercial_inquiry_image)

    login
    get(:index, params: { pattern: image.id })

    assert_redirected_to(image_path(image))
  end

  def test_show_image
    image = images(:peltigera_image)
    assert(ImageVote.where(image: image).many?,
           "Use Image fixture with multiple votes for better coverage")
    num_views = image.num_views
    login
    get(:show, params: { id: image.id })
    assert_template("show", partial: "_form_ccbyncsa25")
    image.reload
    assert_equal(num_views + 1, image.num_views)
    (Image::ALL_SIZES + [:original]).each do |size|
      get(:show, params: { id: image.id, size: size })
      assert_template("show", partial: "_form_ccbyncsa25")
    end
  end

  def test_show_image_nil_user
    image = images(:peltigera_image)
    image.update(user: nil)

    login
    get(:show, params: { id: image.id })

    assert_response(:success)
    assert_template("show", partial: "_form_ccbyncsa25")
  end

  # Prove show works when params include obs
  def test_show_with_obs_param
    obs = observations(:peltigera_obs)
    assert(image = obs.images.first, "Test needs Obs fixture with images")

    login(obs.user.login)

    get(:show, params: { id: image.id, obs: obs.id })
    assert_template("show", partial: "_form_ccbyncsa25")
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

    assert_template("show", partial: "_form_ccbyncsa25")
    assert_equal(num_views + 1, image.reload.num_views)
    (Image::ALL_SIZES + [:original]).each do |size|
      get(:show, params: { id: image.id, size: size })
      assert_template("show", partial: "_form_ccbyncsa25")
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
    query = Query.lookup_and_save(:Image, by_users: user)
    q = @controller.full_q_param(query)
    params = { id: image.id, q: }

    delete_requires_user(:destroy, { action: :show, id: image.id, q: q },
                         params, user.login)

    assert_redirected_to(action: :show, id: next_image.id, q: q)
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

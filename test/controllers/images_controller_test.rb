# frozen_string_literal: true

require("test_helper")

class ImagesControllerTest < FunctionalTestCase
  def check_index_sorted_by(sort_order)
    login
    get(:index, params: { by: sort_order })

    assert_template("index")
    assert_template(partial: "_matrix_box")
    assert_displayed_title("Images by #{sort_order.titleize}")
  end

  # Tests of index, with tests arranged as follows:
  # default subaction; then
  # other subactions in order of @index_subaction_param_keys
  def test_index
    login
    get(:index)
    default_sorted_by = "sort_by_#{::Query::ImageBase.default_order}".to_sym.l

    assert_template("index")
    assert_template(partial: "_matrix_box")
    assert_displayed_title("Images by #{default_sorted_by}")
  end

  def test_index_with_non_default_sort
    check_index_sorted_by("name")
  end

  def test_index_sorted_by_user
    check_index_sorted_by("user")
  end

  def test_index_sorted_by_confidence
    by = "confidence"

    login
    get(:index, params: { by: by })

    assert_template("index")
    assert_template(partial: "_matrix_box")
    assert_displayed_title("Images by Confidence Level")
  end

  def test_index_sorted_by_copyright_holder
    check_index_sorted_by("copyright_holder")
  end

  def test_index_sorted_by_image_quality
    check_index_sorted_by("image_quality")
  end

  def test_index_sorted_by_owners_quality
    by = "owners_quality"

    login
    get(:index, params: { by: by })

    assert_template("index")
    assert_template(partial: "_matrix_box")
    assert_displayed_title("Images by Owner’s Quality")
  end

  def test_index_too_many_pages
    login
    get(:index, params: { page: 1_000_000 })

    # 429 == :too_many_requests. The symbolic response code does not work.
    # Perhaps we're not loading that part of Rack. JDC 2022-08-17
    assert_response(429)
  end

  def test_index_advanced_search_multiple_hits
    obs = observations(:fungi_obs)
    assert(obs.images.many?)
    query = Query.lookup_and_save(:Image, :advanced_search,
                                  name: obs.text_name,
                                  user: obs.user.name,
                                  location: obs.where)
    assert(query.results.many?)

    login
    get(:index,
        params: @controller.query_params(query).merge({ advanced_search: "1" }))

    assert_response(:success)
    assert_template("index")
    assert_template(partial: "_matrix_box")
    assert_displayed_title("Advanced Search")
  end

  def test_index_advanced_search_one_hit
    image = images(:connected_coprinus_comatus_image)
    query = Query.lookup_and_save(:Image, :advanced_search,
                                  name: "Coprinus comatus")
    assert(query.results.one?)

    login
    get(:index,
        params: @controller.query_params(query).merge({ advanced_search: "1" }))

    assert_response(:redirect)
    assert_match(image_path(image), redirect_to_url)
  end

  def test_index_advanced_search_no_hits
    query = Query.lookup_and_save(:Image, :advanced_search,
                                  name: "Don't know",
                                  user: "myself",
                                  content: "Long pink stem and small pink cap",
                                  location: "Eastern Oklahoma")
    assert(query.results.count.zero?)

    login
    get(:index,
        params: @controller.query_params(query).merge({ advanced_search: "1" }))

    assert_flash_text(:runtime_no_matches.l(type: :images.l))
    assert_template("index")
  end

  def test_index_advanced_search_invalid_q_param
    login
    get(:index, params: { q: "xxxxx", advanced_search: "1" })

    assert_flash_text(:advanced_search_bad_q_error.l)
    assert_redirected_to(search_advanced_path)
  end

  def test_index_advanced_search_error
    query = Query.lookup_and_save(:Image, :advanced_search,
                                  name: "Don't know",
                                  user: "myself",
                                  content: "Long pink stem and small pink cap",
                                  location: "Eastern Oklahoma")
    login

    @controller.stub(:show_selected_images, -> { raise(StandardError) }) do
      get(:index,
          params: @controller.query_params(query).
          merge({ advanced_search: "1" }))
    end

    assert_redirected_to(search_advanced_path)
  end

  def test_index_pattern_text_multiple_hits
    pattern = "USA"

    login
    get(:index, params: { pattern: pattern })

    assert_template("index", partial: "_image")
    assert_displayed_title("Images Matching ‘#{pattern}’")
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

  def test_index_by_user
    user = rolf

    login
    get(:index, params: { by_user: user.id })

    assert_template("index")
    assert_template(partial: "_matrix_box")
  end

  def test_index_by_user_bad_user_id
    bad_user_id = observations(:minimal_unknown_obs).id
    assert_empty(User.where(id: bad_user_id), "Test needs different 'bad_id'")

    login
    get(:index, params: { by_user: bad_user_id })

    assert_flash_text(
      :runtime_object_not_found.l(type: "user", id: bad_user_id)
    )
    assert_redirected_to(images_path)
  end

  def test_index_for_project
    project = projects(:bolete_project).id
    login
    get(:index,
        params: { for_project: project })

    assert_template("index", partial: "_image")
  end

  #########################################################

  def test_next_image_ss
    det_unknown =  observations(:detailed_unknown_obs)    # 2 images
    min_unknown =  observations(:minimal_unknown_obs)     # 0 images
    a_campestris = observations(:agaricus_campestris_obs) # 1 image
    c_comatus =    observations(:coprinus_comatus_obs)    # 1 image

    # query 1 (outer)
    outer = Query.lookup_and_save(:Observation,
                                  :in_set, ids: [det_unknown,
                                                 min_unknown,
                                                 a_campestris,
                                                 c_comatus])
    # query 2 (inner for first obs)
    inner = Query.lookup_and_save(:Image, :inside_observation,
                                  outer: outer, observation: det_unknown,
                                  by: :id)

    # Make sure the outer query is working right first.
    outer.current = det_unknown
    new_outer = outer.next
    assert_equal(outer, new_outer)
    assert_equal(min_unknown.id, outer.current_id)
    assert_equal(0, outer.current.images.size)
    new_outer = outer.next
    assert_equal(outer, new_outer)
    assert_equal(a_campestris.id, outer.current_id)
    assert_equal(1, outer.current.images.size)
    new_outer = outer.next
    assert_equal(outer, new_outer)
    assert_equal(c_comatus.id, outer.current_id)
    assert_equal(1, outer.current.images.size)
    new_outer = outer.next
    assert_nil(new_outer)

    # Start with inner at last image of first observation (det_unknown).
    inner.current = det_unknown.images.last.id

    # No more images for det_unknowns, so inner goes to next obs (min_unknown),
    # but this has no images, so goes to next (a_campestris),
    # this has one image (agaricus_campestris_image).  (Shouldn't
    # care that outer query has changed, inner query remembers where it
    # was when inner query was created.)
    assert(new_inner = inner.next)
    assert_not_equal(inner, new_inner)
    assert_equal(images(:agaricus_campestris_image).id, new_inner.current_id)
    new_inner.save # query 3 (inner for third obs)
    save_query = new_inner
    assert(new_new_inner = new_inner.next)
    assert_not_equal(new_inner, new_new_inner)
    assert_equal(images(:connected_coprinus_comatus_image).id,
                 new_new_inner.current_id)
    new_new_inner.save # query 4 (inner for fourth obs)
    assert_nil(new_new_inner.next)

    params = {
      id: det_unknown.images.last.id, # inner for first obs
      params: @controller.query_params(inner).merge({ flow: :next })
    }.flatten
    login
    get(:show, params: params)
    assert_redirected_to(action: :show,
                         id: images(:agaricus_campestris_image).id,
                         params: @controller.query_params(save_query))
  end

  # Test next_image in the context of a search
  def test_next_image_search
    rolfs_favorite_image_id = images(:connected_coprinus_comatus_image).id
    image = Image.find(rolfs_favorite_image_id)

    # Create simple index.
    query = Query.lookup_and_save(:Image, :by_user, user: rolf)
    ids = query.result_ids
    assert(ids.length > 3)
    rolfs_index = ids.index(rolfs_favorite_image_id)
    assert(rolfs_index)
    expected_next = ids[rolfs_index + 1]
    assert(expected_next)

    # See what should happen if we look up an Image search and go to next.
    query.current = image
    assert(new_query = query.next)
    assert_equal(query, new_query)
    assert_equal(expected_next, new_query.current_id)

    # Now do it for real.
    params = {
      id: rolfs_favorite_image_id,
      params: @controller.query_params(query).merge({ flow: :next })
    }.flatten
    login
    get(:show, params: params)
    assert_redirected_to(action: :show, id: expected_next,
                         params: @controller.query_params(query))
  end

  def test_prev_image_ss
    det_unknown =  observations(:detailed_unknown_obs).id
    min_unknown =  observations(:minimal_unknown_obs).id
    a_campestris = observations(:agaricus_campestris_obs).id
    c_comatus =    observations(:coprinus_comatus_obs).id

    outer = Query.lookup_and_save(:Observation,
                                  :in_set, ids: [det_unknown,
                                                 min_unknown,
                                                 a_campestris,
                                                 c_comatus])
    inner = Query.lookup_and_save(:Image, :inside_observation,
                                  outer: outer, observation: a_campestris,
                                  by: :id)

    # Make sure the outer query is working right first.
    outer.current_id = a_campestris
    new_outer = outer.prev
    assert_equal(outer, new_outer)
    assert_equal(min_unknown, outer.current_id)
    assert_equal(0, outer.current.images.size)
    new_outer = outer.prev
    assert_equal(outer, new_outer)
    assert_equal(det_unknown, outer.current_id)
    assert_equal(2, outer.current.images.size)
    new_outer = outer.prev
    assert_nil(new_outer)

    # No more images for a_campestris, so goes to next obs (min_unknown),
    # but this has no images, so goes to next (det_unknown). This has two images
    # whose sort order is unknown because fixture ids are autognerated. So use
    # .second to get the 2nd image and .first to get the 1st.
    # (Shouldn't care that outer query has changed, inner query remembers where
    # it was when inner query was created.)
    inner.current_id = images(:agaricus_campestris_image).id
    assert(new_inner = inner.prev)
    assert_not_equal(inner, new_inner)
    assert_equal(observations(:detailed_unknown_obs).images.second.id,
                 new_inner.current_id)
    assert(new_new_inner = new_inner.prev)
    assert_equal(new_inner, new_new_inner)
    assert_equal(observations(:detailed_unknown_obs).images.first.id,
                 new_inner.current_id)
    assert_nil(new_inner.prev)

    params = {
      id: images(:agaricus_campestris_image).id,
      params: @controller.query_params(inner).merge({ flow: :prev })
    }.flatten
    login
    get(:show, params: params)
    assert_redirected_to(
      action: :show,
      id: observations(:detailed_unknown_obs).images.second.id,
      params: @controller.query_params(QueryRecord.last)
    )
  end

  def test_show_image
    image = images(:peltigera_image)
    assert(ImageVote.where(image: image).count > 1,
           "Use Image fixture with multiple votes for better coverage")
    num_views = image.num_views
    login
    get(:show, params: { id: image.id })
    assert_template("show", partial: "_form_ccbyncsa25")
    image.reload
    assert_equal(num_views + 1, image.num_views)
    (Image.all_sizes + [:original]).each do |size|
      get(:show, params: { id: image.id, size: size })
      assert_template("show", partial: "_form_ccbyncsa25")
    end
  end

  # Prove show works when params include obs
  def test_show_with_obs_param
    obs = observations(:peltigera_obs)
    assert((image = obs.images.first), "Test needs Obs fixture with images")

    login(obs.user.login)

    assert_difference("QueryRecord.count", 2,
                      "images#show from obs-type page should add 2 Query's") do
      get(:show, params: { id: image.id, obs: obs.id })
    end
    assert_template("show", partial: "_form_ccbyncsa25")
    first_query = Query.find(QueryRecord.first.id)
    second_query = Query.find(QueryRecord.second.id)
    assert_equal(Observation, first_query.model)
    assert_equal(Image, second_query.model)
  end

  def test_show_image_with_bad_vote
    image = images(:peltigera_image)
    assert(ImageVote.where(image: image).count > 1,
           "Use Image fixture with multiple votes for better coverage")
    # create invalid vote in order to cover line that rescues an error
    bad_vote = ImageVote.new(image: image, user: nil, value: Image.minimum_vote)
    bad_vote.save!(validate: false)
    num_views = image.num_views

    login
    get(:show, params: { id: image.id })

    assert_template("show", partial: "_form_ccbyncsa25")
    assert_equal(num_views + 1, image.reload.num_views)
    (Image.all_sizes + [:original]).each do |size|
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
    image = user.images.second
    next_image = user.images.first
    obs = image.observations.first
    assert(obs.images.member?(image))
    query = Query.lookup_and_save(:Image, :by_user, user: user)
    q = query.id.alphabetize
    params = { id: image.id, q: q }

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

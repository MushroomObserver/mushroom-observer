# frozen_string_literal: true

require("test_helper")

class ImageControllerTest < FunctionalTestCase
  def test_list_images
    login
    get(:list_images)
    assert_template("list_images", partial: "_image")
  end

  def test_list_images_too_many_pages
    login
    get(:list_images, params: { page: 1_000_000 })
    # 429 == :too_many_requests. The symbolic response code does not work.
    # Perhaps we're not loading that part of Rack. JDC 2022-08-17
    assert_response(429)
  end

  def test_images_by_user
    login
    get(:images_by_user, params: { id: rolf.id })
    assert_template("list_images", partial: "_image")
  end

  def test_index_image_by_user
    login
    get(:index_image, params: { by: "user" })
    assert_select("title", text: "Mushroom Observer: Images by User")
  end

  def test_index_image_by_copyright_holder
    login
    get(:index_image, params: { by: "copyright_holder" })
    assert_select("title",
                  text: "Mushroom Observer: Images by Copyright Holder")
  end

  def test_index_image_by_name
    login
    get(:index_image, params: { by: "name" })
    assert_select("title", text: "Mushroom Observer: Images by Name")
  end

  def test_images_for_project
    login
    get(:images_for_project,
        params: { id: projects(:bolete_project).id })
    assert_template("list_images", partial: "_image")
  end

  def test_next_image_1
    login
    get(:next_image, params: { id: images(:turned_over_image).id })
    # Default sort order is inverse chronological (created_at DESC, id DESC).
    # So here, "next" image is one created immediately previously.
    exp_id = images(:in_situ_image).id
    assert_redirected_to(/#{show_image_path(id: exp_id)}[\b|?]/)
  end

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
      id: det_unknown.images.last.id,
      params: @controller.query_params(inner) # inner for first obs
    }.flatten
    login
    get(:next_image, params: params)
    qp = @controller.query_params(save_query)
    assert_redirected_to(
      show_image_path(id: images(:agaricus_campestris_image).id, params: qp)
    )
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
      params: @controller.query_params(query)
    }.flatten
    login
    get(:next_image, params: params)
    qp = @controller.query_params(query)
    assert_redirected_to(show_image_path(id: expected_next, params: qp))
  end

  def test_prev_image
    login
    # oldest image
    get(:prev_image, params: { id: images(:in_situ_image).id })
    # so "prev" is the 2nd oldest
    exp_id = images(:turned_over_image).id
    assert_redirected_to(/#{show_image_path(id: exp_id)}[\b|?]/)
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
      params: @controller.query_params(inner)
    }.flatten
    login
    get(:prev_image, params: params)
    expected_id = observations(:detailed_unknown_obs).images.second.id
    qp = @controller.query_params(QueryRecord.last)
    assert_redirected_to(show_image_path(id: expected_id, params: qp))
  end

  def test_show_original
    img_id = images(:in_situ_image).id
    login
    get(:show_original, params: { id: img_id })
    assert_redirected_to(show_image_path(size: "full_size", id: img_id))
  end

  def test_show_image
    image = images(:peltigera_image)
    assert(ImageVote.where(image: image).count > 1,
           "Use Image fixture with multiple votes for better coverage")
    num_views = image.num_views
    login
    get(:show_image, params: { id: image.id })
    assert_template("show_image", partial: "_form_ccbyncsa25")
    image.reload
    assert_equal(num_views + 1, image.num_views)
    (Image.all_sizes + [:original]).each do |size|
      get(:show_image, params: { id: image.id, size: size })
      assert_template("show_image", partial: "_form_ccbyncsa25")
    end
  end

  # Prove show works when params include obs
  def test_show_with_obs_param
    obs = observations(:peltigera_obs)
    assert((image = obs.images.first), "Test needs Obs fixture with images")

    login(obs.user.login)

    assert_difference("QueryRecord.count", 2,
                      "show_image from obs-type page should add 2 Query's") do
      get(:show_image, params: { id: image.id, obs: obs.id })
    end
    assert_template("show_image", partial: "_form_ccbyncsa25")
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
    get(:show_image, params: { id: image.id })

    assert_template("show_image", partial: "_form_ccbyncsa25")
    assert_equal(num_views + 1, image.reload.num_views)
    (Image.all_sizes + [:original]).each do |size|
      get(:show_image, params: { id: image.id, size: size })
      assert_template("show_image", partial: "_form_ccbyncsa25")
    end
  end

  def test_show_image_edit_links
    img = images(:in_situ_image)
    proj = projects(:bolete_project)
    assert_equal(mary.id, img.user_id) # owned by mary
    assert(img.projects.include?(proj)) # owned by bolete project
    # dick is only member of project
    assert_equal([dick.id], proj.user_group.users.map(&:id))

    login("rolf")
    get(:show_image, params: { id: img.id })
    assert_select("a[href*=edit_image]", count: 0)
    assert_select("a[href*=destroy_image]", count: 0)
    get(:edit_image, params: { id: img.id })
    assert_response(:redirect)
    get(:destroy_image, params: { id: img.id })
    assert_flash_error

    login("mary")
    get(:show_image, params: { id: img.id })
    assert_select("a[href*=edit_image]", minimum: 1)
    assert_select("a[href*=destroy_image]", minimum: 1)
    get(:edit_image, params: { id: img.id })
    assert_response(:success)

    login("dick")
    get(:show_image, params: { id: img.id })
    assert_select("a[href*=edit_image]", minimum: 1)
    assert_select("a[href*=destroy_image]", minimum: 1)
    get(:edit_image, params: { id: img.id })
    assert_response(:success)
    get(:destroy_image, params: { id: img.id })
    assert_flash_success
  end

  def test_show_image_change_user_default_size
    image = images(:in_situ_image)
    user = users(:rolf)
    assert_equal("medium", user.image_size, "Need different fixture for test")
    login(user.login)

    get(:show_image, params: { id: image.id, size: :small, make_default: "1" })
    assert_equal("small", user.reload.image_size)
  end

  def test_show_image_change_user_vote
    image = images(:peltigera_image)
    user = users(:rolf)
    changed_vote = Image.minimum_vote

    login(user.login)
    get(:show_image, params: { id: image.id, vote: changed_vote, next: true })

    assert_equal(changed_vote, image.reload.users_vote(user),
                 "Failed to change user's vote for image")
  end

  def test_cast_vote
    user = users(:mary)
    image = images(:in_situ_image)
    value = Image.maximum_vote
    login(user.login)

    assert_difference("ImageVote.count", 1, "Failed to cast vote") do
      get(:cast_vote, params: { id: image.id, value: value })
    end
    assert_redirected_to(show_image_path(id: image.id))
    vote = ImageVote.last
    assert(vote.image == image && vote.user == user && vote.value == value,
           "Vote not cast correctly")
  end

  def test_cast_vote_next
    user = users(:mary)
    image = images(:in_situ_image)
    value = Image.maximum_vote
    login(user.login)

    assert_difference("ImageVote.count", 1, "Failed to cast vote") do
      get(:cast_vote, params: { id: image.id, value: value, next: true })
    end
    assert_redirected_to(show_image_path(id: image.id,
                                         q: QueryRecord.last.id.alphabetize))
    vote = ImageVote.last
    assert(vote.image == image && vote.user == user && vote.value == value,
           "Vote not cast correctly")
  end

  def test_image_search
    login
    get(:image_search, params: { pattern: "Notes" })
    assert_template("list_images", partial: "_image")
    assert_equal(:query_title_pattern_search.t(types: "Images",
                                               pattern: "Notes"),
                 @controller.instance_variable_get(:@title))
    get(:image_search, params: { pattern: "Notes", page: 2 })
    assert_template("list_images")
    assert_equal(:query_title_pattern_search.t(types: "Images",
                                               pattern: "Notes"),
                 @controller.instance_variable_get(:@title))
  end

  def test_image_search_next
    login
    get(:image_search, params: { pattern: "Notes" })
    assert_template("list_images", partial: "_image")
  end

  def test_image_search_by_number
    img_id = images(:commercial_inquiry_image).id
    login
    get(:image_search, params: { pattern: img_id })
    assert_redirected_to(show_image_path(id: img_id))
  end

  def test_advanced_search
    query = Query.lookup_and_save(:Image, :advanced_search,
                                  name: "Don't know",
                                  user: "myself",
                                  content: "Long pink stem and small pink cap",
                                  location: "Eastern Oklahoma")
    login
    get(:advanced_search, params: @controller.query_params(query))
    assert_template("list_images")
  end

  def test_advanced_search_invalid_q_param
    login
    get(:advanced_search, params: { q: "xxxxx" })

    assert_flash_text(:advanced_search_bad_q_error.l)
    assert_redirected_to(search_advanced_path)
  end

  def test_advanced_search_error
    query = Query.lookup_and_save(:Image, :advanced_search,
                                  name: "Don't know",
                                  user: "myself",
                                  content: "Long pink stem and small pink cap",
                                  location: "Eastern Oklahoma")
    ImageController.any_instance.expects(:show_selected_images).
      raises(StandardError)
    login

    get(:advanced_search, params: @controller.query_params(query))
    assert_redirected_to(search_advanced_path)
  end

  def test_add_image
    obs1 = observations(:coprinus_comatus_obs)
    obs2 = observations(:minimal_unknown_obs)
    requires_login(:add_image, id: obs1.id)
    assert_form_action(action: "add_image", id: obs1.id)
    # Check that image cannot be added to an observation the user doesn't own.
    get(:add_image, params: { id: obs2.id })
    assert_redirected_to(observation_path(id: obs2.id))
  end

  # Test reusing an image by id number.
  def test_add_image_to_obs
    obs = observations(:coprinus_comatus_obs)
    updated_at = obs.updated_at
    image = images(:disconnected_coprinus_comatus_image)
    assert_not(obs.images.member?(image))
    requires_login(:reuse_image, mode: "observation", obs_id: obs.id,
                                 img_id: image.id)
    assert_redirected_to(observation_path(id: obs.id))
    assert(obs.reload.images.member?(image))
    assert(updated_at != obs.updated_at)
  end

  def test_license_updater
    requires_login(:license_updater)
    assert_form_action(action: "license_updater")
  end

  def test_update_licenses
    example_image    = images(:agaricus_campestris_image)
    user_id          = example_image.user_id
    copyright_holder = example_image.copyright_holder
    old_license      = example_image.license

    target_license = example_image.license
    new_license    = licenses(:ccwiki30)
    assert_not_equal(target_license, new_license)
    assert_equal(0, example_image.copyright_changes.length)

    target_count = Image.where(user_id: user_id,
                               license_id: target_license.id,
                               copyright_holder: copyright_holder).length
    new_count = Image.where(user_id: user_id,
                            license_id: new_license.id,
                            copyright_holder: copyright_holder).length
    assert(target_count.positive?)
    assert(new_count.zero?)

    params = {
      updates: {
        "1" => {
          old_id: target_license.id.to_s,
          new_id: new_license.id.to_s,
          old_holder: copyright_holder,
          new_holder: copyright_holder
        }
      }
    }
    post_requires_login(:license_updater, params)
    assert_template("license_updater")
    assert_equal(10, rolf.reload.contribution)

    target_count_after = Image.where(user_id: user_id,
                                     license_id: target_license.id,
                                     copyright_holder: copyright_holder).length
    new_count_after = Image.where(user_id: user_id,
                                  license_id: new_license.id,
                                  copyright_holder: copyright_holder).length
    assert(target_count_after < target_count)
    assert(new_count_after > new_count)
    assert_equal(target_count_after + new_count_after, target_count + new_count)
    example_image.reload
    assert_equal(new_license.id, example_image.license_id)
    assert_equal(copyright_holder, example_image.copyright_holder)
    assert_equal(1, example_image.copyright_changes.length,
                 "Wrong number of copyright changes")
    assert_equal(old_license.id,
                 example_image.copyright_changes.last.license_id)

    # This empty string caused it to crash in the wild.
    example_image.reload
    example_image.copyright_holder = ""
    example_image.save
    # (note: the above creates a new entry in copyright_changes!!)
    params = {
      updates: {
        "1" => {
          old_id: new_license.id.to_s,
          new_id: new_license.id.to_s,
          old_holder: "",
          new_holder: "A. H. Smith"
        }
      }
    }
    post_requires_login(:license_updater, params)
    assert_template("license_updater")
    example_image.reload
    assert_equal("A. H. Smith", example_image.copyright_holder,
                 "Name of new copyright holder is incorrect")
    assert_equal(3, example_image.copyright_changes.length)
    assert_equal(new_license.id,
                 example_image.copyright_changes.last.license_id)
    assert_equal("", example_image.copyright_changes.last.name,
                 "Name of prior copyright holder is incorrect")
  end

  def test_delete_images
    obs = observations(:detailed_unknown_obs)
    keep = images(:turned_over_image)
    remove = images(:in_situ_image)
    assert(obs.images.member?(keep))
    assert(obs.images.member?(remove))
    assert_equal(remove.id, obs.thumb_image_id)

    selected = {}
    selected[keep.id.to_s] = "no"
    selected[remove.id.to_s] = "yes"
    params = {
      id: obs.id.to_s,
      selected: selected
    }
    post_requires_login(:remove_images, params, "mary")
    assert_redirected_to(observation_path(obs.id))
    assert_equal(10, mary.reload.contribution)
    assert(obs.reload.images.member?(keep))
    assert_not(obs.images.member?(remove))
    assert_equal(keep.id, obs.thumb_image_id)

    selected = {}
    selected[keep.id.to_s] = "yes"
    params = {
      id: obs.id.to_s,
      selected: selected
    }
    post(:remove_images, params: params)
    assert_redirected_to(observation_path(obs.id))
    # Observation gets downgraded to 1 point because it no longer has images.
    # assert_equal(1, mary.reload.contribution)
    assert_equal(10, mary.reload.contribution)
    assert_not(obs.reload.images.member?(keep))
    assert_nil(obs.thumb_image_id)
  end

  def test_destroy_image
    image = images(:turned_over_image)
    obs = image.observations.first
    assert(obs.images.member?(image))
    params = { id: image.id.to_s }
    assert_equal("mary", image.user.login)
    requires_user(:destroy_image, :show_image, params, "mary")
    assert_redirected_to(action: :list_images)
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
    params = { id: image.id.to_s, q: q }

    requires_user(:destroy_image, :show_image, params, user.login)

    assert_redirected_to(show_image_path(id: next_image.id, q: q))
    assert_equal(0, user.reload.contribution)
    assert_not(obs.reload.images.member?(image))
  end

  def test_edit_image
    image = images(:connected_coprinus_comatus_image)
    params = { "id" => image.id.to_s }
    assert(image.user.login == "rolf")
    requires_user(:edit_image, %w[image show_image], params)
    assert_form_action(action: "edit_image", id: image.id.to_s)
  end

  def test_update_image
    image = images(:agaricus_campestris_image)
    obs = image.observations.first
    assert(obs)
    assert(obs.rss_log.nil?)
    new_name = "new nāme.jpg"

    params = {
      "id" => image.id,
      "image" => {
        "when(1i)" => "2001",
        "when(2i)" => "5",
        "when(3i)" => "12",
        "copyright_holder" => "Rolf Singer",
        "notes" => "",
        "original_name" => new_name
      }
    }
    post_requires_login(:edit_image, params)
    assert_redirected_to(show_image_path(id: image.id))
    assert_equal(10, rolf.reload.contribution)

    assert(obs.reload.rss_log)
    assert(obs.rss_log.notes.include?("log_image_updated"))
    assert(obs.rss_log.notes.include?("user #{obs.user.login}"))
    assert(
      obs.rss_log.notes.include?("name Image%20##{image.id}")
    )
    assert_equal(new_name, image.reload.original_name)
  end

  def test_update_image_no_changes
    image = images(:agaricus_campestris_image)
    params = {
      "id" => image.id,
      "image" => {
        "when(1i)" => image.when.year.to_s,
        "when(2i)" => image.when.month.to_s,
        "when(3i)" => image.when.day.to_s,
        "copyright_holder" => image.copyright_holder,
        "notes" => image.notes,
        "original_name" => image.original_name,
        "license" => image.license
      }
    }

    post_requires_login(:edit_image, params)

    assert_flash_text(:runtime_no_changes.l,
                      "Flash should say no changes " \
                      "if no changes made when editing image")
  end

  # Prove that user can remove image from project
  # by updating image without changes
  def test_update_image_unchanged_remove_from_project
    project = projects(:bolete_project)
    assert(project.images.present?,
           "Test needs Project fixture that has an Image")
    image = project.images.first
    user = image.user
    params = {
      "id" => image.id,
      "image" => {
        "when(1i)" => image.when.year.to_s,
        "when(2i)" => image.when.month.to_s,
        "when(3i)" => image.when.day.to_s,
        "copyright_holder" => image.copyright_holder,
        "notes" => image.notes,
        "original_name" => image.original_name,
        "license" => image.license
      },
      project: project
    }
    login(user.login)

    post(:edit_image, params: params)

    assert(project.reload.images.exclude?(image),
           "Failed to remove image from project")
  end

  def test_update_image_save_fail
    image = images(:turned_over_image)
    assert_not_empty(image.projects,
                     "Use Image fixture with a Project for best coverage")
    params = {
      "id" => image.id,
      "image" => {
        "when(1i)" => "2001",
        "when(2i)" => "5",
        "when(3i)" => "12",
        "copyright_holder" => "Rolf Singer",
        "notes" => "",
        "original_name" => "new name"
      }
    }

    login(image.user.login)
    Image.any_instance.stubs(:save).returns(false)
    post(:edit_image, params: params)

    assert(assert_select("#title").text.start_with?("Editing Image"),
           "It should return to form if image save fails")
  end

  def test_remove_images
    obs = observations(:coprinus_comatus_obs)
    params = { id: obs.id }
    assert_equal("rolf", obs.user.login)
    # requires_user et al don't work, these assume too much about path.
    # requires_user(:remove_images, observation_path(id: obs.id))
    get(:remove_images, params: params)
    assert_redirected_to(new_account_login_path)

    # Now login as obs owner
    login(rolf.login)
    get(:remove_images, params: params)
    assert_form_action(action: "remove_images", id: obs.id)
  end

  def test_remove_images_post
    obs = observations(:detailed_unknown_obs)
    images = obs.images
    assert(images.size > 1,
           "Use Observation fixture with multiple images for best coverage")
    user = obs.user
    selected = images.ids.each_with_object({}) do |item, hash|
      hash[item.to_s] = "yes" # "img_id" => "yes" (yes means delete that image˝)
    end
    params = { id: obs.id, selected: selected }

    login(user.login)
    post(:remove_images, params: params)

    assert_empty(obs.reload.images)
  end

  def test_remove_images_for_glossary_term
    glossary_term = glossary_terms(:plane_glossary_term)
    params = { id: glossary_term.id }
    requires_login(:remove_images_for_glossary_term, params)
    assert_form_action(action: "remove_images_for_glossary_term",
                       id: glossary_term.id)
  end

  def test_reuse_image_for_observation
    obs = observations(:agaricus_campestris_obs)
    params = { mode: "observation", obs_id: obs.id }
    assert_equal("rolf", obs.user.login)

    logout
    send(:get, :reuse_image, params: params)
    assert_response(:login, "No user: ")

    login("mary", "testpassword")
    send(:get, :reuse_image, params: params)
    # assert_redirected_to(%r{/#{obs.id}$})
    assert_redirected_to(observation_path(obs.id))

    login("rolf", "testpassword")
    send(:get, :reuse_image, params: params)
    assert_response(:success)
    assert_form_action(action: :reuse_image, mode: "observation",
                       obs_id: obs.id)
  end

  def test_reuse_image_for_observation_all_images
    obs = observations(:agaricus_campestris_obs)
    params = { all_users: 1, mode: "observation", obs_id: obs.id }

    login(obs.user.login)
    get(:reuse_image, params: params)

    assert_form_action(action: :reuse_image, mode: "observation",
                       obs_id: obs.id)
    assert_select("a", { text: :image_reuse_just_yours.l },
                  "Form should have a link to show only the user's images.")
  end

  def test_reuse_image_for_glossary_term
    glossary_term = glossary_terms(:conic_glossary_term)
    params = { id: glossary_term.id }
    requires_login(:reuse_image_for_glossary_term, params)
    assert_form_action(action: "reuse_image_for_glossary_term",
                       id: glossary_term.id)
  end

  def test_reuse_image_for_glossary_term_all_images
    glossary_term = glossary_terms(:conic_glossary_term)
    params = { all_users: 1, id: glossary_term.id }
    requires_login(:reuse_image_for_glossary_term, params)

    assert_form_action(action: "reuse_image_for_glossary_term",
                       id: glossary_term.id)
    assert_select("a", { text: :image_reuse_just_yours.l },
                  "Form should have a link to show only the user's images.")
  end

  def test_reuse_image_by_id
    obs = observations(:agaricus_campestris_obs)
    updated_at = obs.updated_at
    image = images(:commercial_inquiry_image)
    assert_not(obs.images.member?(image))
    params = {
      mode: "observation",
      obs_id: obs.id.to_s,
      img_id: image.id.to_s
    }
    owner = obs.user.login
    assert_not_equal("mary", owner)
    requires_login(:reuse_image, params, "mary")
    # assert_template(controller: :observations, action: :show)
    assert_redirected_to(observation_path(obs.id))
    assert_not(obs.reload.images.member?(image))

    login(owner)
    get(:reuse_image, params: params)
    # assert_template(controller: :observations, action: :show)
    assert_redirected_to(observation_path(obs.id))
    assert(obs.reload.images.member?(image))
    assert(updated_at != obs.updated_at)
  end

  def test_reuse_image_for_glossary_term_post
    glossary_term = glossary_terms(:conic_glossary_term)
    image = images(:commercial_inquiry_image)
    assert_not(glossary_term.images.member?(image))
    params = {
      id: glossary_term.id.to_s,
      img_id: image.id.to_s
    }
    login("mary")
    get(:reuse_image_for_glossary_term, params: params)
    assert_redirected_to(glossary_term_path(glossary_term.id))
    assert(glossary_term.reload.images.member?(image))
  end

  def test_reuse_image_for_glossary_term_post_without_thumbnail
    glossary_term = glossary_terms(:convex_glossary_term)
    image = images(:commercial_inquiry_image)
    assert_empty(glossary_term.images)
    assert_nil(glossary_term.thumb_image)
    params = {
      id: glossary_term.id.to_s,
      img_id: image.id.to_s
    }
    login("mary")
    get(:reuse_image_for_glossary_term, params: params)
    assert_redirected_to(glossary_term_path(glossary_term.id))
    assert(glossary_term.reload.images.member?(image))
    assert_objs_equal(image, glossary_term.thumb_image)
  end

  def test_reuse_image_for_glossary_term_add_image_fails
    GlossaryTerm.any_instance.stubs(:add_image).returns(false)
    glossary_term = glossary_terms(:convex_glossary_term)
    image = images(:commercial_inquiry_image)
    assert_empty(glossary_term.images)
    assert_nil(glossary_term.thumb_image)
    params = {
      id: glossary_term.id.to_s,
      img_id: image.id.to_s
    }
    login("mary")
    get(:reuse_image_for_glossary_term, params: params)
    assert_form_action(action: "reuse_image_for_glossary_term",
                       id: glossary_term.id)
    assert_flash_error
  end

  def test_reuse_image_for_glossary_bad_image_id
    glossary_term = glossary_terms(:conic_glossary_term)
    params = { id: glossary_term.id, img_id: "bad_id" }

    requires_login(:reuse_image_for_glossary_term, params)

    assert_flash_text(:runtime_image_reuse_invalid_id.t(id: params[:img_id]))
  end

  def test_upload_image
    setup_image_dirs
    obs = observations(:coprinus_comatus_obs)
    updated_at = obs.updated_at
    proj = projects(:bolete_project)
    proj.observations << obs
    img_count = obs.images.size
    assert(img_count.positive?)
    assert(obs.thumb_image)
    file = Rack::Test::UploadedFile.new(
      "#{::Rails.root}/test/images/Coprinus_comatus.jpg", "image/jpeg"
    )
    params = {
      id: obs.id,
      image: {
        "when(1i)" => "2007",
        "when(2i)" => "3",
        "when(3i)" => "29",
        copyright_holder: "Douglas Smith",
        notes: "Some notes."
      },
      upload: {
        image1: file,
        image2: "",
        image3: "",
        image4: ""
      },
      project: {
        # This is a good test: Rolf doesn't belong to the Bolete project,
        # but we still want this image to attach to that project by default,
        # because the *observation* is attached to that project.
        "id_#{proj.id}" => "1"
      }
    }
    File.stub(:rename, false) do
      login("rolf", "testpassword")
      post(:add_image, params: params)
    end
    assert_equal(20, rolf.reload.contribution)
    assert(obs.reload.images.size == (img_count + 1))
    assert(updated_at != obs.updated_at)
    message = :runtime_image_uploaded_image.t(
      name: "##{obs.images.last.id}"
    )
    assert_flash_text(/#{message}/)
    img = Image.last
    assert_obj_list_equal([obs], img.observations)
    assert_obj_list_equal([proj], img.projects)
    assert_false(obs.gps_hidden)
    assert_false(img.gps_stripped)
  end

  def test_reuse_image_for_observation_bad_image_id
    obs = observations(:agaricus_campestris_obs)
    params = { mode: "observation", obs_id: obs.id, img_id: "bad_id" }

    login(obs.user.login)
    get(:reuse_image, params: params)

    assert_flash_text(:runtime_image_reuse_invalid_id.t(id: params[:img_id]))
  end

  # Prove there is no change when user tries to change profile image to itself
  def test_reuse_user_profile_image_as_itself
    user = users(:rolf)
    assert((img = user.image), "Test needs User fixture with profile image")
    params = { mode: "profile", img_id: img.id }

    login(user.login)
    get(:reuse_image, params: params)

    assert_equal(img, user.image)
    assert_flash_text(:runtime_no_changes.l)
  end

  def test_add_images_empty
    login("rolf")
    obs = observations(:coprinus_comatus_obs)
    post(:add_image, params: { id: obs.id })
    assert_flash_text(/no changes/i)
  end

  def test_add_images_strip_gps
    login("rolf")
    obs = observations(:coprinus_comatus_obs)
    obs.update_attribute(:gps_hidden, true)

    setup_image_dirs
    fixture = "#{MO.root}/test/images/geotagged.jpg"
    fixture = Rack::Test::UploadedFile.new(fixture, "image/jpeg")

    post(:add_image,
         params: { id: obs.id,
                   image: { "when(1i)" => "2007",
                            "when(2i)" => "3",
                            "when(3i)" => "29",
                            copyright_holder: "Douglas Smith",
                            notes: "Some notes." },
                   upload: { image1: fixture,
                             image2: "",
                             image3: "",
                             image4: "" } })

    img = Image.last
    assert_true(img.gps_stripped)
  end

  def test_add_images_process_image_fail
    login("rolf")
    obs = observations(:coprinus_comatus_obs)
    setup_image_dirs
    fixture = "#{MO.root}/test/images/geotagged.jpg"
    fixture = Rack::Test::UploadedFile.new(fixture, "image/jpeg")
    Image.any_instance.stubs(:process_image).returns(false)

    post(:add_image,
         params: { id: obs.id,
                   image: { "when(1i)" => "2007",
                            "when(2i)" => "3",
                            "when(3i)" => "29",
                            copyright_holder: "Douglas Smith",
                            notes: "Some notes." },
                   upload: { image1: fixture,
                             image2: "",
                             image3: "",
                             image4: "" } })

    assert_flash_error("image.process_image failure should cause flash error")
    assert_redirected_to(observation_path(obs.id))
  end

  # This is what would happen when user first opens form.
  def test_reuse_image_for_user
    requires_login(:reuse_image, mode: "profile")
    assert_template("reuse_image", partial: "_image_reuse")
    assert_form_action(action: "reuse_image", mode: "profile")
  end

  # This would happen if user clicked on image.
  def test_reuse_image_for_user_post1
    image = images(:commercial_inquiry_image)
    params = { mode: "profile", img_id: image.id.to_s }
    requires_login(:reuse_image, params)
    assert_redirected_to(user_path(rolf.id))
    assert_equal(rolf.id, session[:user_id])
    assert_equal(image.id, rolf.reload.image_id)
  end

  # This would happen if user typed in id and submitted.
  def test_reuse_image_for_user_post2
    image = images(:commercial_inquiry_image)
    params = { mode: "profile", img_id: image.id.to_s }
    post_requires_login(:reuse_image, params)
    assert_redirected_to(user_path(rolf.id))
    assert_equal(rolf.id, session[:user_id])
    assert_equal(image.id, rolf.reload.image_id)
  end

  def test_reuse_image_strip_gps_failed
    login("mary")
    obs = observations(:minimal_unknown_obs)
    img = images(:in_situ_image)
    obs.update_attribute(:gps_hidden, true)
    assert_false(img.gps_stripped)
    post(:reuse_image,
         params: { mode: "observation", obs_id: obs.id, img_id: img.id })
    assert_false(img.reload.gps_stripped)
  end

  def test_reuse_image_strip_gps_worked
    login("mary")
    obs = observations(:minimal_unknown_obs)
    img = images(:in_situ_image)
    obs.update_attribute(:gps_hidden, true)
    assert_false(img.gps_stripped)

    setup_image_dirs
    fixture = "#{MO.root}/test/images/geotagged.jpg"
    orig_file = img.local_file_name("orig")
    path = orig_file.sub(%r{/[^/]*$}, "")
    FileUtils.mkdir_p(path) unless File.directory?(path)
    FileUtils.cp(fixture, orig_file)

    post(:reuse_image,
         params: { mode: "observation", obs_id: obs.id, img_id: img.id })
    assert_true(img.reload.gps_stripped)
    assert_not_equal(File.size(fixture),
                     File.size(img.local_file_name("orig")))
  end

  # Test setting anonymity of all image votes.
  def test_bulk_image_vote_anonymity_thingy
    img1 = images(:in_situ_image)
    img2 = images(:commercial_inquiry_image)
    img1.change_vote(mary, 1, anon: false)
    img2.change_vote(mary, 2, anon: true)
    img1.change_vote(rolf, 3, anon: true)
    img2.change_vote(rolf, 4, anon: false)

    assert_not(ImageVote.find_by(image_id: img1.id, user_id: mary.id).anonymous)
    assert(ImageVote.find_by(image_id: img2.id, user_id: mary.id).anonymous)
    assert(ImageVote.find_by(image_id: img1.id, user_id: rolf.id).anonymous)
    assert_not(ImageVote.find_by(image_id: img2.id, user_id: rolf.id).anonymous)

    requires_login(:bulk_vote_anonymity_updater)
    assert_template("bulk_vote_anonymity_updater")

    login("mary")
    post(:bulk_vote_anonymity_updater,
         params: { commit: :image_vote_anonymity_make_anonymous.l })
    assert_redirected_to(edit_account_preferences_path)
    assert(ImageVote.find_by(image_id: img1.id, user_id: mary.id).anonymous)
    assert(ImageVote.find_by(image_id: img2.id, user_id: mary.id).anonymous)
    assert(ImageVote.find_by(image_id: img1.id, user_id: rolf.id).anonymous)
    assert_not(ImageVote.find_by(image_id: img2.id, user_id: rolf.id).anonymous)

    login("rolf")
    post(:bulk_vote_anonymity_updater,
         params: { commit: :image_vote_anonymity_make_public.l })
    assert_redirected_to(edit_account_preferences_path)
    assert(ImageVote.find_by(image_id: img1.id, user_id: mary.id).anonymous)
    assert(ImageVote.find_by(image_id: img2.id, user_id: mary.id).anonymous)
    assert_not(ImageVote.find_by(image_id: img1.id, user_id: rolf.id).anonymous)
    assert_not(ImageVote.find_by(image_id: img2.id, user_id: rolf.id).anonymous)
  end

  def test_bulk_vote_anonymity_updater_bad_commit_param
    login("rolf")
    post(:bulk_vote_anonymity_updater, params: { commit: "bad commit" })

    assert_flash_error
    assert_redirected_to(edit_account_preferences_path)
  end

  def test_original_filename_visibility
    # Rolf's image, original name: "Name with áč€εиts.gif"
    img_id = images(:agaricus_campestris_image).id
    login("mary")

    rolf.keep_filenames = "toss"
    rolf.save
    get(:show_image, params: { id: img_id })
    assert_false(@response.body.include?("áč€εиts"))

    rolf.keep_filenames = "keep_but_hide"
    rolf.save
    get(:show_image, params: { id: img_id })
    assert_false(@response.body.include?("áč€εиts"))

    rolf.keep_filenames = "keep_and_show"
    rolf.save
    get(:show_image, params: { id: img_id })
    assert_true(@response.body.include?("áč€εиts"))

    login("rolf")

    rolf.keep_filenames = "toss"
    rolf.save
    get(:show_image, params: { id: img_id })
    assert_true(@response.body.include?("áč€εиts"))

    rolf.keep_filenames = "keep_but_hide"
    rolf.save
    get(:show_image, params: { id: img_id })
    assert_true(@response.body.include?("áč€εиts"))

    rolf.keep_filenames = "keep_and_show"
    rolf.save
    get(:show_image, params: { id: img_id })
    assert_true(@response.body.include?("áč€εиts"))
  end

  def test_bulk_original_filename_purge
    imgs = Image.where("original_name != '' AND user_id = #{rolf.id}")
    assert(imgs.any?)

    login("rolf")
    get(:bulk_filename_purge)
    imgs = Image.where("original_name != '' AND user_id = #{rolf.id}")
    assert(imgs.empty?)
  end

  def test_project_checkboxes
    proj1 = projects(:eol_project)
    proj2 = projects(:bolete_project)
    obs1 = observations(:minimal_unknown_obs)
    obs2 = observations(:detailed_unknown_obs)
    img1 = images(:in_situ_image)
    img2 = images(:commercial_inquiry_image)
    assert_users_equal(mary, obs1.user)
    assert_users_equal(mary, obs2.user)
    assert_users_equal(mary, img1.user)
    assert_users_equal(rolf, img2.user)
    assert_obj_list_equal([],      obs1.projects)
    assert_obj_list_equal([proj2], obs2.projects)
    assert_obj_list_equal([proj2], img1.projects)
    assert_obj_list_equal([],      img2.projects)
    assert_obj_list_equal([rolf, mary, katrina], proj1.user_group.users)
    assert_obj_list_equal([dick], proj2.user_group.users)

    # NOTE: It is impossible, apparently, to get edit_image to fail,
    # so there is no way to test init_project_vars_for_reload().

    login("rolf")
    get(:add_image, params: { id: obs1.id })
    assert_response(:redirect)
    get(:add_image, params: { id: obs2.id })
    assert_response(:redirect)
    get(:edit_image, params: { id: img1.id })
    assert_response(:redirect)
    get(:edit_image, params: { id: img2.id })
    assert_project_checks(proj1.id => :unchecked, proj2.id => :no_field)

    login("mary")
    get(:add_image, params: { id: obs1.id })
    assert_project_checks(proj1.id => :unchecked, proj2.id => :no_field)
    get(:add_image, params: { id: obs2.id })
    assert_project_checks(proj1.id => :unchecked, proj2.id => :checked)
    get(:edit_image, params: { id: img1.id })
    assert_project_checks(proj1.id => :unchecked, proj2.id => :checked)
    get(:edit_image, params: { id: img2.id })
    assert_response(:redirect)

    login("dick")
    get(:add_image, params: { id: obs2.id })
    assert_project_checks(proj1.id => :no_field, proj2.id => :checked)
    get(:edit_image, params: { id: img1.id })
    assert_project_checks(proj1.id => :no_field, proj2.id => :checked)
    get(:edit_image, params: { id: img2.id })
    assert_response(:redirect)
    proj1.add_image(img1)
    get(:edit_image, params: { id: img1.id })
    assert_project_checks(proj1.id => :checked_but_disabled,
                          proj2.id => :checked)
  end

  def assert_project_checks(project_states)
    project_states.each do |id, state|
      assert_checkbox_state("project_id_#{id}", state)
    end
  end

  def test_show_user_profile_image
    assert(rolf.image_id)
    login
    get(:show_image, params: { id: rolf.image_id })

    conic = glossary_terms(:conic_glossary_term)
    assert(conic.thumb_image_id)
    get(:show_image, params: { id: conic.thumb_image_id })
  end

  def test_show_image_has_okay_link
    login
    image = images(:in_situ_image)
    image.update(ok_for_ml: false)
    get(:show_image, params: { id: image.id })
    assert_true(@response.body.include?("type=image&amp;value=1"))
  end

  def test_transform_rotate_left
    run_transform(opr: "rotate_left")
  end

  def test_transform_rotate_right
    run_transform(opr: "rotate_right")
  end

  def test_transform_mirror
    run_transform(opr: "mirror")
  end

  def test_transform_bad_op
    run_transform(opr: "bad_op", flash: %(Invalid operation "bad_op"))
  end

  def run_transform(opr:, flash: :image_show_transform_note.l)
    image = images(:in_situ_image)
    user = image.user
    params = { id: image.id, op: opr, size: user.image_size }

    login(user.login)
    get(:transform_image, params: params)

    # Asserting the flash text is the best I can do because Image.transform
    # does not transform images in the text environment. 2022-08-19 JDC
    assert_flash_text(flash)
    assert_redirected_to(show_image_path(id: image.id))
  end

  # Prove that if size is provided and is
  def test_transform_show_with_size
    image = images(:in_situ_image)
    user = image.user
    size = "huge"
    assert_not_equal(size, user.image_size, "Test needs a different size value")
    params = { id: image.id, op: "rotate_left", size: size }

    login(user.login)
    get(:transform_image, params: params)

    # Asserting the flash text is the best I can do because Image.transform
    # does not transform images in the text environment. 2022-08-19 JDC
    assert_flash_text(:image_show_transform_note.l)
    assert_redirected_to(show_image_path(id: image.id, size: size))
  end
end

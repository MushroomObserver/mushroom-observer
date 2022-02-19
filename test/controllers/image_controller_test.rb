# frozen_string_literal: true

require("test_helper")

class ImageControllerTest < FunctionalTestCase
  def test_list_images
    get_with_dump(:list_images)
    assert_template("list_images", partial: "_image")
  end

  def test_images_by_user
    get_with_dump(:images_by_user, id: rolf.id)
    assert_template("list_images", partial: "_image")
  end

  def test_images_for_project
    get_with_dump(:images_for_project, id: projects(:bolete_project).id)
    assert_template("list_images", partial: "_image")
  end

  def test_next_image
    get_with_dump(:next_image, id: images(:turned_over_image).id)
    # Default sort order is inverse chronological (created_at DESC, id DESC).
    # So here, "next" image is one created immediately previously.
    assert_redirected_to(%r{show_image/#{images(:in_situ_image).id}[\b|?]})
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
    get(:next_image, params)
    assert_redirected_to(action: "show_image",
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
      params: @controller.query_params(query)
    }.flatten
    get(:next_image, params)
    assert_redirected_to(action: "show_image", id: expected_next,
                         params: @controller.query_params(query))
  end

  def test_prev_image
    get_with_dump(:prev_image, id: images(:in_situ_image).id) # oldest image
    # so "prev" is the 2nd oldest
    assert_redirected_to(%r{show_image/#{images(:turned_over_image).id}[\b|?]})
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
    get(:prev_image, params)
    assert_redirected_to(
      action: "show_image",
      id: observations(:detailed_unknown_obs).images.second.id,
      params: @controller.query_params(QueryRecord.last)
    )
  end

  def test_show_original
    img_id = images(:in_situ_image).id
    get_with_dump(:show_original, id: img_id)
    assert_redirected_to(action: "show_image", size: "full_size", id: img_id)
  end

  def test_show_image
    image = images(:in_situ_image)
    num_views = image.num_views
    get_with_dump(:show_image, id: image.id)
    assert_template("show_image", partial: "_form_ccbyncsa25")
    image.reload
    assert_equal(num_views + 1, image.num_views)
    (Image.all_sizes + [:original]).each do |size|
      get(:show_image, id: image.id, size: size)
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
    get(:show_image, id: img.id)
    assert_select("a[href*=edit_image]", count: 0)
    assert_select("a[href*=destroy_image]", count: 0)
    get(:edit_image, id: img.id)
    assert_response(:redirect)
    get(:destroy_image, id: img.id)
    assert_flash_error

    login("mary")
    get(:show_image, id: img.id)
    assert_select("a[href*=edit_image]", minimum: 1)
    assert_select("a[href*=destroy_image]", minimum: 1)
    get(:edit_image, id: img.id)
    assert_response(:success)

    login("dick")
    get(:show_image, id: img.id)
    assert_select("a[href*=edit_image]", minimum: 1)
    assert_select("a[href*=destroy_image]", minimum: 1)
    get(:edit_image, id: img.id)
    assert_response(:success)
    get(:destroy_image, id: img.id)
    assert_flash_success
  end

  def test_image_search
    get_with_dump(:image_search, pattern: "Notes")
    assert_template("list_images", partial: "_image")
    assert_equal(:query_title_pattern_search.t(types: "Images",
                                               pattern: "Notes"),
                 @controller.instance_variable_get("@title"))
    get_with_dump(:image_search, pattern: "Notes", page: 2)
    assert_template("list_images")
    assert_equal(:query_title_pattern_search.t(types: "Images",
                                               pattern: "Notes"),
                 @controller.instance_variable_get("@title"))
  end

  def test_image_search_next
    get_with_dump(:image_search, pattern: "Notes")
    assert_template("list_images", partial: "_image")
  end

  def test_image_search_by_number
    img_id = images(:commercial_inquiry_image).id
    get_with_dump(:image_search, pattern: img_id)
    assert_redirected_to(action: "show_image", id: img_id)
  end

  def test_advanced_search
    query = Query.lookup_and_save(:Image, :advanced_search,
                                  name: "Don't know",
                                  user: "myself",
                                  content: "Long pink stem and small pink cap",
                                  location: "Eastern Oklahoma")
    get(:advanced_search, @controller.query_params(query))
    assert_template("list_images")
  end

  def test_advanced_search_invalid_q_param
    get(:advanced_search, params: { q: "xxxxx" })

    assert_flash_text(:advanced_search_bad_q_error.l)
    assert_redirected_to(observer_advanced_search_form_path)
  end

  def test_add_image
    requires_login(:add_image, id: observations(:coprinus_comatus_obs).id)
    assert_form_action(action: "add_image",
                       id: observations(:coprinus_comatus_obs).id)
    # Check that image cannot be added to an observation the user doesn't own.
    get_with_dump(:add_image, id: observations(:minimal_unknown_obs).id)
    assert_redirected_to(controller: "observer", action: "show_observation")
  end

  # Test reusing an image by id number.
  def test_add_image_to_obs
    obs = observations(:coprinus_comatus_obs)
    updated_at = obs.updated_at
    image = images(:disconnected_coprinus_comatus_image)
    assert_not(obs.images.member?(image))
    requires_login(:reuse_image, mode: "observation", obs_id: obs.id,
                                 img_id: image.id)
    assert_redirected_to(controller: :observer, action: :show_observation,
                         id: obs.id)
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
    assert_redirected_to(controller: :observer, action: :show_observation)
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
    post(:remove_images, params)
    assert_redirected_to(controller: "observer", action: "show_observation")
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
    assert_redirected_to(action: :show_image, id: image.id)
    assert_equal(10, rolf.reload.contribution)

    assert(obs.reload.rss_log)
    assert(obs.rss_log.notes.include?("log_image_updated"))
    assert(obs.rss_log.notes.include?("user #{obs.user.login}"))
    assert(
      obs.rss_log.notes.include?("name Image%20##{image.id}")
    )
    assert_equal(new_name, image.reload.original_name)
  end

  def test_remove_images
    obs = observations(:coprinus_comatus_obs)
    params = { id: obs.id }
    assert_equal("rolf", obs.user.login)
    requires_user(
      :remove_images,
      { controller: :observer, action: :show_observation, id: obs.id },
      params
    )
    assert_form_action(action: "remove_images", id: obs.id)
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
    send(:get, :reuse_image, params)
    assert_response(:login, "No user: ")

    login("mary", "testpassword")
    send(:get, :reuse_image, params)
    # assert_redirected_to(%r{/#{obs.id}$})
    assert_redirected_to(controller: :observer, action: :show_observation,
                         id: obs.id)

    login("rolf", "testpassword")
    send(:get_with_dump, :reuse_image, params)
    assert_response(:success)
    assert_form_action(action: :reuse_image, mode: "observation",
                       obs_id: obs.id)
  end

  def test_reuse_image_for_glossary_term
    glossary_term = glossary_terms(:conic_glossary_term)
    params = { id: glossary_term.id }
    requires_login(:reuse_image_for_glossary_term, params)
    assert_form_action(action: "reuse_image_for_glossary_term",
                       id: glossary_term.id)
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
    # assert_template(controller: :observer, action: :show_observation)
    assert_redirected_to(controller: :observer, action: :show_observation,
                         id: obs.id)
    assert_not(obs.reload.images.member?(image))

    login(owner)
    get_with_dump(:reuse_image, params)
    # assert_template(controller: "observer", action: "show_observation")
    assert_redirected_to(controller: :observer, action: :show_observation,
                         id: obs.id)
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
    get_with_dump(:reuse_image_for_glossary_term, params)
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
    get(:reuse_image_for_glossary_term, params)
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
    get(:reuse_image_for_glossary_term, params)
    assert_form_action(action: "reuse_image_for_glossary_term",
                       id: glossary_term.id)
    assert_flash_error
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
      post_with_dump(:add_image, params)
    end
    assert_equal(20, rolf.reload.contribution)
    assert(obs.reload.images.size == (img_count + 1))
    assert(updated_at != obs.updated_at)
    message = :runtime_image_uploaded_image.t(
      name: "#" + obs.images.last.id.to_s
    )
    assert_flash_text(/#{message}/)
    img = Image.last
    assert_obj_list_equal([obs], img.observations)
    assert_obj_list_equal([proj], img.projects)
    assert_false(obs.gps_hidden)
    assert_false(img.gps_stripped)
  end

  def test_add_images_empty
    login("rolf")
    obs = observations(:coprinus_comatus_obs)
    post(:add_image, id: obs.id)
    assert_flash_text(/no changes/i)
  end

  def test_add_images_strip_gps
    login("rolf")
    obs = observations(:coprinus_comatus_obs)
    obs.update_attribute(:gps_hidden, true)

    setup_image_dirs
    fixture = "#{MO.root}/test/images/geotagged.jpg"
    fixture = Rack::Test::UploadedFile.new(fixture, "image/jpeg")

    post(
      :add_image,
      id: obs.id,
      image: {
        "when(1i)" => "2007",
        "when(2i)" => "3",
        "when(3i)" => "29",
        copyright_holder: "Douglas Smith",
        notes: "Some notes."
      },
      upload: {
        image1: fixture,
        image2: "",
        image3: "",
        image4: ""
      }
    )

    img = Image.last
    assert_true(img.gps_stripped)
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
    assert_redirected_to(controller: :observer, action: :show_user,
                         id: rolf.id)
    assert_equal(rolf.id, session[:user_id])
    assert_equal(image.id, rolf.reload.image_id)
  end

  # This would happen if user typed in id and submitted.
  def test_reuse_image_for_user_post2
    image = images(:commercial_inquiry_image)
    params = { mode: "profile", img_id: image.id.to_s }
    post_requires_login(:reuse_image, params)
    assert_redirected_to(controller: :observer, action: :show_user,
                         id: rolf.id)
    assert_equal(rolf.id, session[:user_id])
    assert_equal(image.id, rolf.reload.image_id)
  end

  def test_reuse_image_strip_gps_failed
    login("mary")
    obs = observations(:minimal_unknown_obs)
    img = images(:in_situ_image)
    obs.update_attribute(:gps_hidden, true)
    assert_false(img.gps_stripped)
    post(:reuse_image, mode: "observation", obs_id: obs.id, img_id: img.id)
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

    post(:reuse_image, mode: "observation", obs_id: obs.id, img_id: img.id)
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
         commit: :image_vote_anonymity_make_anonymous.l)
    assert_redirected_to(controller: :account, action: :prefs)
    assert(ImageVote.find_by(image_id: img1.id, user_id: mary.id).anonymous)
    assert(ImageVote.find_by(image_id: img2.id, user_id: mary.id).anonymous)
    assert(ImageVote.find_by(image_id: img1.id, user_id: rolf.id).anonymous)
    assert_not(ImageVote.find_by(image_id: img2.id, user_id: rolf.id).anonymous)

    login("rolf")
    post(:bulk_vote_anonymity_updater,
         commit: :image_vote_anonymity_make_public.l)
    assert_redirected_to(controller: :account, action: :prefs)
    assert(ImageVote.find_by(image_id: img1.id, user_id: mary.id).anonymous)
    assert(ImageVote.find_by(image_id: img2.id, user_id: mary.id).anonymous)
    assert_not(ImageVote.find_by(image_id: img1.id, user_id: rolf.id).anonymous)
    assert_not(ImageVote.find_by(image_id: img2.id, user_id: rolf.id).anonymous)
  end

  def test_original_filename_visibility
    # Rolf's image, original name: "Name with áč€εиts.gif"
    img_id = images(:agaricus_campestris_image).id
    login("mary")

    rolf.keep_filenames = :toss
    rolf.save
    get(:show_image, id: img_id)
    assert_false(@response.body.include?("áč€εиts"))

    rolf.keep_filenames = :keep_but_hide
    rolf.save
    get(:show_image, id: img_id)
    assert_false(@response.body.include?("áč€εиts"))

    rolf.keep_filenames = :keep_and_show
    rolf.save
    get(:show_image, id: img_id)
    assert_true(@response.body.include?("áč€εиts"))

    login("rolf")

    rolf.keep_filenames = :toss
    rolf.save
    get(:show_image, id: img_id)
    assert_true(@response.body.include?("áč€εиts"))

    rolf.keep_filenames = :keep_but_hide
    rolf.save
    get(:show_image, id: img_id)
    assert_true(@response.body.include?("áč€εиts"))

    rolf.keep_filenames = :keep_and_show
    rolf.save
    get(:show_image, id: img_id)
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
    get(:add_image, id: obs1.id)
    assert_response(:redirect)
    get(:add_image, id: obs2.id)
    assert_response(:redirect)
    get(:edit_image, id: img1.id)
    assert_response(:redirect)
    get(:edit_image, id: img2.id)
    assert_project_checks(proj1.id => :unchecked, proj2.id => :no_field)

    login("mary")
    get(:add_image, id: obs1.id)
    assert_project_checks(proj1.id => :unchecked, proj2.id => :no_field)
    get(:add_image, id: obs2.id)
    assert_project_checks(proj1.id => :unchecked, proj2.id => :checked)
    get(:edit_image, id: img1.id)
    assert_project_checks(proj1.id => :unchecked, proj2.id => :checked)
    get(:edit_image, id: img2.id)
    assert_response(:redirect)

    login("dick")
    get(:add_image, id: obs2.id)
    assert_project_checks(proj1.id => :no_field, proj2.id => :checked)
    get(:edit_image, id: img1.id)
    assert_project_checks(proj1.id => :no_field, proj2.id => :checked)
    get(:edit_image, id: img2.id)
    assert_response(:redirect)
    proj1.add_image(img1)
    get(:edit_image, id: img1.id)
    assert_project_checks(proj1.id => :checked_but_disabled,
                          proj2.id => :checked)
  end

  def assert_project_checks(project_states)
    for id, state in project_states
      assert_checkbox_state("project_id_#{id}", state)
    end
  end

  def test_show_user_profile_image
    assert(rolf.image_id)
    get(:show_image, id: rolf.image_id)

    conic = glossary_terms(:conic_glossary_term)
    assert(conic.thumb_image_id)
    get(:show_image, id: conic.thumb_image_id)
  end
end

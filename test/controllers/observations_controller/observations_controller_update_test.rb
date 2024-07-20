# frozen_string_literal: true

require("test_helper")

class ObservationsControllerUpdateTest < FunctionalTestCase
  tests ObservationsController

  ##############################################################################

  # ----------------------------------------------------------------
  #  Test :edit and :update (note :update uses method: :put)
  # ----------------------------------------------------------------

  # (Sorry, these used to all be edit/update_observation, now they're
  # confused because of the naming stuff.)
  def test_edit_observation_form
    obs = observations(:coprinus_comatus_obs)
    assert_equal("rolf", obs.user.login)
    params = { id: obs.id }
    requires_user(:edit,
                  [{ controller: "/observations", action: :show }],
                  params)

    assert_form_action(action: :update, id: obs.id)

    # image notes field must be textarea -- not just text -- because text
    # is inline and would drops any newlines in the image notes
    assert_select("textarea[id = 'good_image_#{obs.images.first.id}_notes']",
                  count: 1)
  end

  def test_update_observation
    obs = observations(:detailed_unknown_obs)
    updated_at = obs.rss_log.updated_at
    new_where = "Somewhere In, Japan"
    new_notes = { other: "blather blather blather" }
    new_specimen = false
    img = images(:in_situ_image)
    params = {
      id: obs.id,
      observation: {
        notes: new_notes,
        place_name: new_where,
        "when(1i)" => "2001",
        "when(2i)" => "2",
        "when(3i)" => "3",
        specimen: new_specimen,
        thumb_image_id: "0"
      },
      good_image_ids: "#{img.id} #{images(:turned_over_image).id}",
      good_image: {
        img.id => {
          notes: "new notes",
          original_name: "new name",
          copyright_holder: "someone else",
          "when(1i)" => "2012",
          "when(2i)" => "4",
          "when(3i)" => "6",
          license_id: licenses(:ccwiki30).id
        }
      },
      log_change: "1"
    }
    put_requires_user(
      :update,
      [{ controller: "/observations", action: :show }],
      params,
      "mary"
    )
    assert_redirected_to(/#{new_location_path}/)
    assert_equal(10, rolf.reload.contribution)
    obs = assigns(:observation)
    assert_equal(new_where, obs.where)
    assert_equal("2001-02-03", obs.when.to_s)
    assert_equal(new_notes, obs.notes)
    assert_equal(new_specimen, obs.specimen)
    assert_not_equal(updated_at, obs.rss_log.updated_at)
    assert_not_equal(0, obs.thumb_image_id)
    img = img.reload
    assert_equal("new notes", img.notes)
    assert_equal("new name", img.original_name)
    assert_equal("someone else", img.copyright_holder)
    assert_equal("2012-04-06", img.when.to_s)
    assert_equal(licenses(:ccwiki30), img.license)
  end

  def test_update_observation_no_logging
    obs = observations(:detailed_unknown_obs)
    updated_at = obs.rss_log.updated_at
    where = "Somewhere, China"
    params = {
      id: obs.id,
      observation: {
        place_name: where,
        when: obs.when,
        notes: obs.notes,
        specimen: obs.specimen
      },
      log_change: "0"
    }
    put_requires_user(
      :update,
      [{ controller: "/observations", action: :show }],
      params,
      "mary"
    )
    assert_redirected_to(/#{new_location_path}/)
    assert_equal(10, rolf.reload.contribution)
    obs = assigns(:observation)
    assert_equal(where, obs.where)
    assert_equal(updated_at, obs.rss_log.updated_at)
  end

  def test_update_observation_bad_place_name
    obs = observations(:detailed_unknown_obs)
    new_where = "test_update_observation"
    new_notes = { other: "blather blather blather" }
    new_specimen = false
    params = {
      id: obs.id,
      observation: {
        place_name: new_where,
        "when(1i)" => "2001",
        "when(2i)" => "2",
        "when(3i)" => "3",
        notes: new_notes,
        specimen: new_specimen,
        thumb_image_id: "0"
      },
      log_change: "1"
    }
    put_requires_user(
      :update,
      [{ controller: "/observations", action: :show }],
      params,
      "mary"
    )
    assert_response(:success) # Which really means failure
  end

  def test_update_observation_with_another_users_image
    img1 = images(:in_situ_image)
    img2 = images(:turned_over_image)
    img3 = images(:commercial_inquiry_image)

    obs = observations(:detailed_unknown_obs)
    obs.images << img3
    obs.save
    obs.reload

    assert_equal(img1.user_id, obs.user_id)
    assert_equal(img2.user_id, obs.user_id)
    assert_not_equal(img3.user_id, obs.user_id)

    img_ids = obs.images.map(&:id)
    assert_equal([img1.id, img2.id, img3.id], img_ids)

    old_img1_notes = img1.notes
    old_img3_notes = img3.notes

    params = {
      id: obs.id,
      observation: {
        place_name: obs.place_name,
        when: obs.when,
        notes: obs.notes,
        specimen: obs.specimen,
        thumb_image_id: "0"
      },
      good_image_ids: img_ids.map(&:to_s).join(" "),
      good_image: {
        img2.id => { notes: "new notes for two" },
        img3.id => { notes: "new notes for three" }
      }
    }
    login("mary")
    put(:update, params: params)
    assert_redirected_to(action: :show)
    assert_flash_success
    assert_equal(old_img1_notes, img1.reload.notes)
    assert_equal("new notes for two", img2.reload.notes)
    assert_equal(old_img3_notes, img3.reload.notes)
  end

  def test_update_observation_with_non_image
    obs = observations(:minimal_unknown_obs)
    file = Rack::Test::UploadedFile.new(
      Rails.root.join("test/fixtures/projects.yml").to_s, "text/plain"
    )
    params = {
      id: obs.id,
      observation: {
        place_name: obs.place_name,
        when: obs.when,
        notes: obs.notes,
        specimen: obs.specimen,
        thumb_image_id: "0"
      },
      good_image_ids: "",
      good_image: {},
      image: {
        "0" => {
          image: file,
          when: Time.zone.now
        }
      }
    }
    login("mary")
    put(:update, params: params)

    # 200 :success means means failure!
    assert_response(
      :success,
      "Expected 200 (OK), Got #{@response.status} (#{@response.message})"
    )
    assert_flash_error
  end

  def test_update_observation_strip_images
    login("mary")
    obs = observations(:detailed_unknown_obs)

    setup_image_dirs
    fixture = "#{MO.root}/test/images/geotagged.jpg"
    fixture = Rack::Test::UploadedFile.new(fixture, "image/jpeg")

    old_img1 = images(:turned_over_image)
    old_img2 = images(:in_situ_image)
    assert_false(old_img1.gps_stripped)
    assert_false(old_img2.gps_stripped)

    orig_file = old_img1.full_filepath("orig")
    path = orig_file.sub(%r{/[^/]*$}, "")
    FileUtils.mkdir_p(path) unless File.directory?(path)
    FileUtils.cp(fixture, orig_file)

    put(
      :update,
      params: {
        id: obs.id,
        observation: {
          gps_hidden: "1"
        },
        good_image_ids: "#{old_img1.id} #{old_img2.id}",
        image: {
          "0" => {
            image: fixture,
            copyright_holder: "me",
            when: Time.zone.now
          }
        }
      }
    )

    obs.reload
    old_img1.reload
    old_img2.reload

    assert_equal(3, obs.images.length)
    new_img = (obs.images - [old_img1, old_img2]).first

    assert_true(new_img.gps_stripped)
    # We have script/process_image disabled for tests, so it doesn't actually
    # strip the uploaded image.
    # assert_not_equal(File.size(fixture),
    #                  File.size(new_img.full_filepath("orig")))

    # Make sure it stripped the image which had already been created.
    assert_true(old_img1.reload.gps_stripped)
    assert_not_equal(File.size(fixture),
                     File.size(old_img1.full_filepath("orig")))

    # Second pre-existing image has missing file, so stripping should fail.
    assert_false(old_img2.reload.gps_stripped)
  end

  # --------------------------------------------------------------------
  #  Test notes with template
  # --------------------------------------------------------------------

  # Prove that edit_observation has correct note fields and content:
  # Template fields first, in template order; then orphaned fields in order
  # in which they appear in observation, then Other
  def test_edit_observation_with_notes_template
    obs    = observations(:templater_noteless_obs)
    user   = obs.user
    params = {
      id: obs.id,
      observation: {
        place_name: obs.location.name,
        lat: "",
        lng: "",
        alt: "",
        "when(1i)" => obs.when.year,
        "when(2i)" => obs.when.month,
        "when(3i)" => obs.when.day,
        specimen: "0",
        thumb_image_id: "0",
        notes: obs.notes
      },
      herbarium_record: { herbarium_name: "", accession_number: "" },
      username: user.login,
      naming: {
        vote: { value: "3" }
      }
    }

    login(user.login)
    get(:edit, params: params)
    assert_page_has_correct_notes_areas(
      expect_areas: { Cap: "", Nearby_trees: "", odor: "",
                      Observation.other_notes_key => "" }
    )

    obs         = observations(:templater_other_notes_obs)
    params[:id] = obs.id
    params[:observation][:notes] = obs.notes
    get(:edit, params: params)
    assert_page_has_correct_notes_areas(
      expect_areas: { Cap: "", Nearby_trees: "", odor: "",
                      Observation.other_notes_key => "some notes" }
    )
  end

  def test_update_observation_with_notes_template
    # Prove notes_template works when editing Observation without notes
    obs = observations(:templater_noteless_obs)
    user = obs.user
    notes = {
      Cap: "dark red",
      Nearby_trees: "?",
      odor: "farinaceous"
    }
    params = {
      id: obs.id,
      observation: { notes: notes }
    }
    login(user.login)
    put(:update, params: params)
    assert_redirected_to(action: :show, id: obs.id)
    assert_equal(notes, obs.reload.notes)
  end
end

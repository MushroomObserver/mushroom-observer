# frozen_string_literal: true

require("test_helper")

class ObservationsControllerUpdateTest < FunctionalTestCase
  tests ObservationsController

  # ----------------------------------------------------------------
  #  Test :edit and :update (note :update uses method: :put)
  # ----------------------------------------------------------------

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
    img_id = obs.images.first.id
    assert_select("textarea[id = 'observation_good_image_#{img_id}_notes']",
                  count: 1)
  end

  def test_edit_observation_form_with_duplicate_note_field
    obs = observations(:template_and_orphaned_notes_obs)
    user = obs.user
    login(user.login)
    key = obs.notes.keys.find { |k| k.to_s.include?("_") }.to_s
    template = key.tr("_", " ")
    user_option = template.upcase
    alt_option = "Alt #{template}"
    user.notes_template += ", #{user_option}, #{alt_option}"
    user.save!
    params = { id: obs.id }
    get(:edit, params:)
    assert_select("textarea[name='observation[notes][#{key}]']",
                  count: 0)
    assert_select("textarea[name='observation[notes][#{key.upcase}]']")
    assert_select(
      "textarea[name='observation[notes][#{alt_option.tr(" ", "_")}]']"
    )
  end

  # The Geolocation section opens when the observation has coordinates,
  # so its checkbox has to agree -- it rendered unchecked over an open
  # section full of coordinates, and clicking it to "fix" that collapsed
  # the section instead (#5002).
  def test_edit_checks_geolocation_when_the_observation_has_coordinates
    obs = observations(:unknown_with_lat_lng)
    assert(obs.lat.present?, "fixture needs coordinates")
    login(obs.user.login)

    get(:edit, params: { id: obs.id })

    assert_select("input[type=checkbox][name='observation[has_geolocation]']" \
                  "[checked]")
  end

  def test_edit_leaves_geolocation_unchecked_without_coordinates
    obs = observations(:minimal_unknown_obs)
    obs.update_columns(lat: nil, lng: nil)
    login(obs.user.login)

    get(:edit, params: { id: obs.id })

    assert_select("input[type=checkbox][name='observation[has_geolocation]']" \
                  "[checked]", count: 0)
  end

  # Editing the primary of a multi-member occurrence, a sibling key it
  # doesn't store is an :inherit row -- a disabled textarea plus buttons
  # with Inherit active and the sibling value as an adopt button.
  def test_edit_primary_offers_inherited_notes_adopt_rows
    primary = observations(:coprinus_comatus_obs)
    sibling = observations(:detailed_unknown_obs)
    [primary, sibling].each { |obs| obs.update_column(:occurrence_id, nil) }
    primary.update!(notes: { Cap: "red" })
    sibling.update!(notes: { Substrate: "on birch" })
    occ = Occurrence.create!(user: primary.user, primary_observation: primary)
    primary.update!(occurrence: occ)
    sibling.update!(occurrence: occ)
    login(primary.user.login)

    get(:edit, params: { id: primary.id })

    assert_select("[data-controller='notes-adopt']")
    assert_select(
      "textarea[name='observation[notes][Substrate]'][disabled]"
    )
    # The disabled textarea shows the value it inherits (the sibling's).
    assert_select("textarea[name='observation[notes][Substrate]']",
                  text: "on birch")
    assert_select("button[data-notes-action='inherit'].active")
    assert_select("button[data-notes-value='on birch']")
  end

  # A key the primary DOES store, whose sibling holds a different value,
  # is a :set row -- an editable textarea plus a This Observation button
  # (active) and the sibling value as an adopt button.
  def test_edit_primary_offers_adopt_for_owned_key_when_sibling_differs
    primary = observations(:coprinus_comatus_obs)
    sibling = observations(:detailed_unknown_obs)
    [primary, sibling].each { |obs| obs.update_column(:occurrence_id, nil) }
    primary.update!(notes: { Cap: "red" })
    sibling.update!(notes: { Cap: "brown" })
    occ = Occurrence.create!(user: primary.user, primary_observation: primary)
    primary.update!(occurrence: occ)
    sibling.update!(occurrence: occ)
    login(primary.user.login)

    get(:edit, params: { id: primary.id })

    assert_select("textarea[name='observation[notes][Cap]']:not([disabled])")
    assert_select("button[data-notes-action='current'].active")
    assert_select("button[data-notes-value='brown'][data-notes-action='adopt']")
  end

  # A shared key whose value AGREES across the occurrence still gets the
  # buttons (This Observation/Inherit/Hide) -- just no adopt button -- so
  # the UI is consistent regardless of whether the values differ.
  def test_edit_primary_renders_buttons_for_agreeing_shared_key
    primary = observations(:coprinus_comatus_obs)
    sibling = observations(:detailed_unknown_obs)
    [primary, sibling].each { |obs| obs.update_column(:occurrence_id, nil) }
    primary.update!(notes: { Cap: "red" })
    sibling.update!(notes: { Cap: "red" }) # same value -> agrees
    occ = Occurrence.create!(user: primary.user, primary_observation: primary)
    primary.update!(occurrence: occ)
    sibling.update!(occurrence: occ)
    login(primary.user.login)

    get(:edit, params: { id: primary.id })

    assert_select("[data-controller='notes-adopt']")
    assert_select("textarea[name='observation[notes][Cap]']")
    assert_select("button[data-notes-action='current'].active")
    assert_select("button[data-notes-action='adopt']", count: 0)
  end

  # A blank submitted for a sibling-held key is preserved (a deliberate
  # suppression of the inherited value); a blank for a key no sibling
  # holds is dropped as usual.
  def test_update_primary_preserves_blank_only_for_sibling_keys
    primary = observations(:coprinus_comatus_obs)
    sibling = observations(:detailed_unknown_obs)
    [primary, sibling].each { |obs| obs.update_column(:occurrence_id, nil) }
    primary.update!(notes: { Cap: "red" })
    sibling.update!(notes: { Substrate: "on birch" })
    occ = Occurrence.create!(user: primary.user, primary_observation: primary)
    primary.update!(occurrence: occ)
    sibling.update!(occurrence: occ)
    login(primary.user.login)

    put(:update, params: {
          id: primary.id,
          observation: {
            place_name: primary.where,
            "when(1i)" => primary.when.year.to_s,
            "when(2i)" => primary.when.month.to_s,
            "when(3i)" => primary.when.day.to_s,
            notes: { Cap: "red", Substrate: "", Ephemeral: "" }
          }
        })

    primary.reload
    # Substrate: a sibling holds it -> blank preserved as a suppression.
    assert(primary.notes.key?(:Substrate))
    assert(primary.notes[:Substrate].blank?)
    # Ephemeral: no sibling holds it -> blank dropped.
    assert_not(primary.notes.key?(:Ephemeral))
    assert_equal("red", primary.notes[:Cap])
    # The show-page merge now suppresses the inherited Substrate value.
    assert_not(occ.reload.merged_notes.key?(:Substrate))
  end

  def test_collector_can_edit_observation
    obs = observations(:newbie_obs)
    login("foray_newbie")
    params = { id: obs.id }
    get(:edit, params: params)
    assert_response(:success)
  end

  def test_can_edit_observation
    obs = observations(:coprinus_comatus_obs)
    login("foray_newbie")
    params = { id: obs.id }
    get(:edit, params: params)
    assert_response(:redirect)
  end

  # A read-only reflection (#4214) can't be edited on MO even by its
  # owner — the edit form redirects with a warning. The permission check
  # runs first, so only the owner (who would otherwise pass) sees the
  # reflection warning.
  def test_edit_reflection_redirects_with_warning
    obs = observations(:imported_inat_obs)
    obs.update_column(:reflected_at, Time.zone.now)
    login(obs.user.login)

    get(:edit, params: { id: obs.id })

    assert_redirected_to(action: :show, id: obs.id)
    assert_flash_warning
  end

  # A non-owner hitting edit on a reflection gets the same
  # permission-denied error as on any observation they can't edit —
  # not the reflection warning (Copilot review on #4852).
  def test_edit_reflection_as_non_owner_gets_permission_error
    obs = observations(:imported_inat_obs)
    obs.update_column(:reflected_at, Time.zone.now)
    non_owner = users(:mary)
    assert_not_equal(obs.user_id, non_owner.id)
    login(non_owner.login)

    get(:edit, params: { id: obs.id })

    assert_redirected_to(action: :show, id: obs.id)
    assert_flash_error
  end

  def test_update_reflection_is_blocked
    obs = observations(:imported_inat_obs)
    original_notes = obs.notes
    obs.update_column(:reflected_at, Time.zone.now)
    login(obs.user.login)

    put(:update, params: {
          id: obs.id,
          observation: { place_name: "Somewhere Else, Japan",
                         notes: { other: "changed on MO" } }
        })

    assert_redirected_to(action: :show, id: obs.id)
    assert_flash_warning
    assert_equal(original_notes, obs.reload.notes,
                 "a reflection's notes must not change through update")
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
        thumb_image_id: "0",
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

  # Regression test for issue #3995:
  # Removing the thumbnail image via edit form leaves thumb_image_id nil
  # even when other images remain on the observation.
  def test_update_observation_remove_thumbnail_reassigns
    obs = observations(:detailed_unknown_obs)
    thumb = images(:in_situ_image)
    other = images(:turned_over_image)
    assert_equal(thumb.id, obs.thumb_image_id,
                 "Fixture should have in_situ_image as thumbnail")
    assert_includes(obs.image_ids, other.id,
                    "Fixture should have turned_over_image attached")

    login("mary")
    # Simulate what the JS does: remove the thumbnail image from
    # good_image_ids and clear thumb_image_id (set to empty string).
    put(:update, params: {
          id: obs.id,
          observation: {
            place_name: obs.place_name,
            when: obs.when,
            notes: obs.notes.to_h,
            specimen: obs.specimen,
            thumb_image_id: "",
            good_image_ids: other.id.to_s
          }
        })

    obs.reload
    assert_not_includes(obs.image_ids, thumb.id,
                        "Thumbnail image should have been detached")
    assert_includes(obs.image_ids, other.id,
                    "Other image should still be attached")
    assert_not_nil(obs.thumb_image_id,
                   "thumb_image_id should be reassigned, not nil")
    assert_equal(other.id, obs.thumb_image_id,
                 "thumb_image_id should be the remaining image")
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
        notes: obs.notes.to_h,
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

    img_ids = obs.images.reorder(created_at: :asc).map(&:id)
    assert_equal([img1.id, img2.id, img3.id], img_ids)

    old_img1_notes = img1.notes
    old_img3_notes = img3.notes

    params = {
      id: obs.id,
      observation: {
        place_name: obs.place_name,
        when: obs.when,
        notes: obs.notes.to_h,
        specimen: obs.specimen,
        thumb_image_id: "0",
        good_image_ids: img_ids.join(" "),
        good_image: {
          img2.id => { notes: "new notes for two" },
          img3.id => { notes: "new notes for three" }
        }
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
        notes: obs.notes.to_h,
        specimen: obs.specimen,
        thumb_image_id: "0",
        good_image_ids: "",
        good_image: {},
        image: {
          "0" => {
            image: file,
            when: Time.zone.now
          }
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
          gps_hidden: "1",
          good_image_ids: "#{old_img1.id} #{old_img2.id}",
          image: {
            "0" => {
              image: fixture,
              copyright_holder: "me",
              when: Time.zone.now
            }
          }
        }
      }
    )

    obs.reload
    old_img1.reload
    old_img2.reload

    assert_equal(3, obs.images.length)
    new_img = (obs.images - [old_img1, old_img2]).first

    # process_image's synchronous strip_original_gps? call runs regardless
    # of Rails.env.test? (only the resize/transfer Image::Processor#process
    # call is skipped in test) -- the new upload's file genuinely exists on
    # disk once move_original places it, so the strip genuinely succeeds.
    assert_true(new_img.gps_stripped)

    # Make sure it stripped the image which had already been created.
    assert_true(old_img1.reload.gps_stripped)
    assert_not_equal(File.size(fixture),
                     File.size(old_img1.full_filepath("orig")))

    # Second pre-existing image has missing file, so stripping should fail.
    assert_false(old_img2.reload.gps_stripped)
  end

  ##############################################################################
  #  Location name validation
  def obs_for_user(user)
    # We need an obs owned by each user to test editing (adding) locations.
    # Roy doesn't have a simple one, but we need him for scientific_format.
    case user.login
    when "rolf"
      observations(:agaricus_campestros_obs)
    when "roy"
      obs = observations(:agaricus_campestras_obs)
      obs.user_id = user.id
      obs.save
      obs
    end
  end

  def modified_obs_params(params, user)
    obs = obs_for_user(user)
    # params[:observation] = obs.attributes.merge(params[:observation] || {})
    params[:username] = user.login
    params[:id] = obs.id
    params
  end

  def location_name_exists(params, user)
    name = Location.user_format(user, params[:observation][:place_name])
    Location.find_by(name:) || Location.is_unknown?(name)
  end

  # Test constructing observations in various ways (with minimal namings)
  def generic_update_observation(params, l_num, user = rolf)
    l_count = Location.count
    params  = modified_obs_params(params, user)
    put_requires_user(
      :update,
      [{ controller: "/observations", action: :show }],
      params,
      user.login
    )

    begin
      if l_num.positive? || (location_name_exists(params, user) && l_num.zero?)
        assert_redirected_to(action: :show)
      else
        assert_select("#dubious_location_messages")
      end
    rescue Minitest::Assertion => e
      flash = get_last_flash.to_s.dup.sub!(/^(\d)/, "")
      message = "#{e}\n" \
      "Flash messages: (level #{Regexp.last_match(1)})\n" \
      "< #{flash} >\n"
      flunk(message)
    end

    assert_equal(l_count + l_num, Location.count, "Wrong Location count")
  end

  # The ones that should pass here now need to match fixtures, in order to
  # generate a location_id, or they will be rejected.
  def test_update_observation_dubious_place_names
    # Location box necessary for new locations (these are all non-fixtures).
    params = {
      location: { north: 35, south: 34, east: -117, west: -118 }
    }
    # Test a reversed name with a scientific user
    where = "USA, Massachusetts, Reversed"
    generic_update_observation(
      params.merge({ observation: { place_name: where, location_id: -1 } }),
      1, roy
    )

    # Test an existing name - should allow, but use existing location
    where = locations(:salt_point).name
    generic_update_observation(
      params.merge({ observation: { place_name: where, location_id: -1 } }),
      0
    )
    assert_equal(locations(:salt_point).id,
                 obs_for_user(rolf).reload.location_id)

    # Test missing space.
    where = "Reversible, Massachusetts,USA"
    generic_update_observation(
      params.merge({ observation: { place_name: where, location_id: -1 } }),
      0
    )

    # Test a bogus country name
    where = "Bogus, Massachusetts, UAS"
    generic_update_observation(
      params.merge({ observation: { place_name: where, location_id: -1 } }),
      0
    )
    where = "UAS, Massachusetts, Bogus"
    generic_update_observation(
      params.merge({ observation: { place_name: where, location_id: -1 } }),
      0, roy
    )

    # Test a bad state name
    where = "Bad State Name, USA"
    generic_update_observation(
      params.merge({ observation: { place_name: where, location_id: -1 } }),
      0
    )
    where = "USA, Bad State Name"
    generic_update_observation(
      params.merge({ observation: { place_name: where, location_id: -1 } }),
      0, roy
    )

    # Test mix of city and county
    where = "Burbank, Los Angeles Co., California, USA"
    generic_update_observation(
      params.merge({ observation: { place_name: where, location_id: -1 } }),
      1
    )
    # Location should now already exist (because of the above).
    where = "USA, California, Los Angeles Co., Burbank"
    generic_update_observation(
      params.merge({ observation: { place_name: where, location_id: -1 } }),
      0, roy
    )

    # Test mix of city and county
    where = "USA, Massachusetts, Barnstable Co., Falmouth"
    generic_update_observation(
      params.merge({ observation: { place_name: where, location_id: -1 } }),
      1, roy
    )

    # Test some bad terms
    where = "Some County, Ohio, USA"
    generic_update_observation(
      params.merge({ observation: { place_name: where, location_id: -1 } }),
      0
    )
    where = "Old Rd, Ohio, USA"
    generic_update_observation(
      params.merge({ observation: { place_name: where, location_id: -1 } }),
      0
    )
    where = "Old Rd., Ohio, USA"
    generic_update_observation(
      params.merge({ observation: { place_name: where, location_id: -1 } }),
      1
    )

    # Test some acceptable additions
    where = "near Burbank, Southern California, USA"
    generic_update_observation(
      params.merge({ observation: { place_name: where, location_id: -1 } }),
      1
    )
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

  # Covers ensure_thumb_image falling back to sibling occurrence images
  # when all own images are removed.
  def test_update_observation_thumb_falls_back_to_sibling_image
    obs = observations(:detailed_unknown_obs)
    sibling = observations(:minimal_unknown_obs)
    sibling_img = images(:in_situ_image)

    # Build an occurrence linking obs and sibling
    occ = Occurrence.create!(
      user: obs.user, primary_observation: obs
    )
    obs.update!(occurrence: occ)
    sibling.update!(occurrence: occ)

    # Attach sibling_img to sibling (ensure it's there)
    unless sibling.image_ids.include?(sibling_img.id)
      sibling.images << sibling_img
    end

    # Remove all of obs's own images
    own_ids = obs.image_ids
    login(obs.user.login)
    put(:update, params: {
          id: obs.id,
          observation: {
            place_name: obs.place_name,
            when: obs.when,
            notes: obs.notes.to_h,
            specimen: obs.specimen,
            thumb_image_id: "",
            good_image_ids: ""
          }
        })

    obs.reload
    assert_empty(obs.image_ids & own_ids,
                 "Own images should have been removed")
    assert_not_nil(obs.thumb_image_id,
                   "thumb should fall back to sibling image")
    assert_includes(
      occ.observations.joins(:images).pluck("images.id"),
      obs.thumb_image_id,
      "thumb should be a sibling occurrence image"
    )
  end

  # Issue #4737: the JS uploader creates the Image before the form
  # submits, so at update time the chosen thumb_image_id is a real image
  # that isn't attached to the observation yet. It must survive the
  # update instead of being reverted to an already-attached image.
  def test_update_observation_new_image_can_be_thumbnail
    obs = observations(:detailed_unknown_obs)
    new_image = images(:disconnected_coprinus_comatus_image)
    # The JS uploader creates the image as the logged-in user.
    new_image.update_columns(user_id: obs.user_id)
    assert_not_includes(obs.image_ids, new_image.id)

    login(obs.user.login)
    put(:update, params: {
          id: obs.id,
          observation: {
            place_name: obs.place_name,
            when: obs.when,
            notes: obs.notes.to_h,
            specimen: obs.specimen,
            thumb_image_id: new_image.id.to_s,
            good_image_ids: (obs.image_ids + [new_image.id]).join(" ")
          }
        })

    obs.reload
    assert_includes(obs.image_ids, new_image.id,
                    "New image should be attached to the observation")
    assert_equal(new_image.id, obs.thumb_image_id,
                 "Newly uploaded image chosen as thumbnail should stick")
  end

  # ---------- field slip code on update ----------

  def test_update_adds_field_slip_code
    obs = observations(:minimal_unknown_obs)
    login(obs.user.login)
    fs = field_slips(:field_slip_no_obs)
    # Detach from any existing occurrence
    obs.update!(occurrence: nil)

    put(:update, params: {
          id: obs.id,
          observation: obs_params(obs),
          field_code: fs.code
        })
    obs.reload
    assert_not_nil(obs.occurrence,
                   "Observation should have an occurrence")
    assert_equal(fs.id, obs.occurrence.field_slip_id,
                 "Occurrence should link to the field slip")
  end

  def test_update_clears_field_slip_code
    obs = observations(:minimal_unknown_obs)
    login(obs.user.login)
    fs = field_slips(:field_slip_no_obs)

    # Assign a field slip (detach from old occurrence first)
    obs.update!(occurrence: nil)
    obs.field_slip = fs
    obs.save!
    assert_not_nil(obs.reload.occurrence_id)

    put(:update, params: {
          id: obs.id,
          observation: obs_params(obs),
          field_code: ""
        })
    obs.reload
    assert_nil(obs.occurrence_id,
               "Observation should have no occurrence")
  end

  # Force `@observation.save` to return false on the update path so
  # we exercise the `save_observation` failure branch (flash_error
  # + `@any_errors = true`). Must pass changed attributes — the
  # save path is guarded by `@observation.changed?`.
  def test_update_observation_save_fails
    obs = observations(:minimal_unknown_obs)
    login(obs.user.login)
    params_with_change = obs_params(obs).merge(notes: { Other: "Changed" })

    obs.stub(:save, false) do
      # `find_observation!` calls Observation.edit_includes.safe_find.
      Observation.stub(:edit_includes, Observation) do
        Observation.stub(:safe_find, obs) do
          put(:update,
              params: { id: obs.id, observation: params_with_change })
        end
      end
    end

    assert_flash(:runtime_no_save_observation)
    # Re-renders the edit form rather than redirecting.
    assert_response(:success)
  end

  def test_update_invalid_field_slip_code
    obs = observations(:minimal_unknown_obs)
    login(obs.user.login)
    original_occ_id = obs.occurrence_id

    # Code with only digits fails FieldSlip validation
    put(:update, params: {
          id: obs.id,
          observation: obs_params(obs),
          field_code: "12345"
        })
    assert_flash_error
    obs.reload
    assert_equal(original_occ_id, obs.occurrence_id,
                 "Observation should remain unchanged")
  end

  # `validate_field_slip` rejects both of these before the save, so the
  # post-save branches only fire when the slip changed underneath us
  # between validation and application. A real race can't be staged, so
  # the status is stubbed — the point is that the branch reports rather
  # than failing silently.
  def test_update_flags_field_slip_that_turns_invalid_after_validation
    assert_field_slip_race_reported(:invalid)
  end

  def test_update_flags_field_slip_that_fills_after_validation
    assert_field_slip_race_reported(:too_many)
  end

  # Unchecking one project box moves every observation of the occurrence,
  # so the flash has to say how many rather than letting the rest go
  # unmentioned. See #4932.
  def test_unchecking_a_project_reports_the_whole_collection
    project = projects(:bolete_project)
    obs = observations(:minimal_unknown_obs)
    sibling = observations(:detailed_unknown_obs)
    occ = Occurrence.create!(user: mary, primary_observation: obs)
    [obs, sibling].each do |o|
      o.update!(occurrence: occ)
      project.add_observation(o)
    end

    login("mary") # a bolete member, so the checkbox is hers to change
    put(:update,
        params: { id: obs.id,
                  observation: obs_params(obs).merge(project_ids: [""]) })

    assert_not_includes(project.reload.observations, obs)
    assert_not_includes(project.observations, sibling)
    assert_includes(get_last_flash.to_s.as_displayed,
                    :removed_from_project_with_siblings.t(
                      count: 2, project: project.title
                    ).as_displayed)
  end

  # An image edit that fails to save reports the image's own errors
  # rather than silently dropping the edit. Image validations are
  # self-correcting (they truncate rather than reject), so the failure
  # has to be forced.
  def test_failed_image_edit_reports_the_images_errors
    obs = observations(:coprinus_comatus_obs)
    image = obs.images.first
    image.define_singleton_method(:save) do |*|
      errors.add(:base, :validate_image_user_missing)
      false
    end
    login(obs.user.login)

    Image.stub(:safe_find, image) do
      put(:update,
          params: { id: obs.id,
                    observation: obs_params(obs).merge(
                      good_image: { image.id.to_s => { notes: "revised" } }
                    ) })
    end

    assert_flash_error
  end

  # Update assigned `notes` from the raw params AFTER resolving them, so
  # every field-slip note resolution was computed and then thrown away.
  # Create never had the bug (it assigns notes first). See #4932.
  def test_update_wraps_other_codes_when_flagged
    obs = observations(:minimal_unknown_obs)
    login(obs.user.login)

    put(:update,
        params: { id: obs.id, inat: "1",
                  observation: obs_params(obs).merge(
                    notes: { Other_Codes: "123456" }
                  ) })

    assert_equal(FieldSlipNotesBuilder.inat_link("123456"),
                 obs.reload.notes[:Other_Codes])
  end

  # The checkbox submits "0" when unticked (its hidden sidecar), which
  # has to put the value back to the bare code -- otherwise unticking
  # looks broken, since the box re-renders checked off a stored link.
  def test_update_unwraps_other_codes_when_unflagged
    obs = observations(:minimal_unknown_obs)
    stored = FieldSlipNotesBuilder.inat_link("123456")
    obs.update!(notes: { Other_Codes: stored })
    login(obs.user.login)

    put(:update,
        params: { id: obs.id, inat: "0",
                  observation: obs_params(obs).merge(
                    notes: { Other_Codes: stored }
                  ) })

    assert_equal("123456", obs.reload.notes[:Other_Codes])
  end

  # No `inat` param at all means the checkbox was never rendered (no
  # field code in play); a stored link must survive untouched.
  def test_update_without_inat_param_leaves_other_codes_alone
    obs = observations(:minimal_unknown_obs)
    stored = FieldSlipNotesBuilder.inat_link("123456")
    obs.update!(notes: { Other_Codes: stored })
    login(obs.user.login)

    put(:update,
        params: { id: obs.id,
                  observation: obs_params(obs).merge(
                    notes: { Other_Codes: stored }
                  ) })

    assert_equal(stored, obs.reload.notes[:Other_Codes])
  end

  # "Id by" resolves through the project's aliases on edit, not just on
  # create -- "RS" is an eol_project alias for rolf.
  def test_update_resolves_id_by_through_project_aliases
    obs = observations(:minimal_unknown_obs)
    project = projects(:eol_project)
    login(obs.user.login)

    put(:update,
        params: { id: obs.id,
                  observation: obs_params(obs).merge(
                    project_ids: [project.id.to_s],
                    notes: { Field_Slip_ID_By: "RS" }
                  ) })

    assert_equal(rolf.textile_name, obs.reload.notes[:Field_Slip_ID_By])
  end

  private

  def assert_field_slip_race_reported(status)
    obs = observations(:minimal_unknown_obs)
    login(obs.user.login)

    @controller.define_singleton_method(:update_field_slip) { |*| status }
    begin
      put(:update,
          params: { id: obs.id, observation: obs_params(obs) })
    ensure
      @controller.singleton_class.remove_method(:update_field_slip)
    end

    assert_flash_error
  end

  def obs_params(obs)
    {
      place_name: obs.place_name,
      "when(1i)" => obs.when.year.to_s,
      "when(2i)" => obs.when.month.to_s,
      "when(3i)" => obs.when.day.to_s,
      specimen: obs.specimen,
      thumb_image_id: obs.thumb_image_id.to_s,
      good_image_ids: obs.image_ids.join(" ")
    }
  end
end

# frozen_string_literal: true

require("test_helper")

# Tests of the shared Images::ReuseController -- the "attach an
# existing image" index serving the observation / glossary_term /
# profile pages. `target_type`/`target_id` are passed explicitly on
# every request here (set as query params on the routes, but
# controller tests dispatch directly rather than through the router).
# `update` is a RESTful member action on the image itself
# (`params[:id]` is always the Image's id, not the target's).
module Images
  class ReuseControllerTest < FunctionalTestCase
    PLACEHOLDER_ID =
      Views::Controllers::Images::Reuse::Index::Form::PLACEHOLDER_ID

    ##########################################################################
    # Invalid target_type

    def test_index_with_unknown_target_type_is_not_found
      login("rolf")
      get(:index, params: { target_type: "Bogus", target_id: "1" })

      assert_response(:not_found)
    end

    ##########################################################################
    # Observation target

    def test_reuse_image_page_access
      obs = observations(:agaricus_campestris_obs)
      params = { target_id: obs.id, target_type: "Observation" }
      assert_equal("rolf", obs.user.login)

      logout
      get(:index, params: params)
      assert_response(:login, "No user: ")

      login("mary", "testpassword")
      get(:index, params: params)
      assert_redirected_to(permanent_observation_path(obs.id))

      login("rolf", "testpassword")
      get(:index, params: params)

      assert_response(:success)
      assert_form_action(action: :update, id: PLACEHOLDER_ID,
                         target_type: "Observation", target_id: obs.id)
    end

    def test_reuse_image_page_access__all_images
      obs = observations(:agaricus_campestris_obs)
      params = { all_users: 1, target_id: obs.id,
                 target_type: "Observation" }

      login(obs.user.login)
      get(:index, params: params)

      assert_select("option", { text: :image_reuse_just_yours.l },
                    "Toggle should have an option to show only the " \
                    "user's images.")
    end

    # layout_count: 1 forces 2 pages out of mary's 2 image fixtures.
    def test_reuse_image_page_shows_pagination_when_multiple_pages
      obs = observations(:minimal_unknown_obs)
      assert_equal("mary", obs.user.login)
      mary.update!(layout_count: 1)

      login("mary")
      get(:index, params: { target_id: obs.id, target_type: "Observation" })

      assert_select(".pagination_numbers a", { text: "Next" },
                    "Page with multiple pages of images to reuse " \
                    "should show a pagination nav")
    end

    def test_add_image_to_obs_by_id
      obs = observations(:coprinus_comatus_obs)
      updated_at = obs.updated_at
      image = images(:disconnected_coprinus_comatus_image)
      assert_not(obs.images.member?(image))
      post_requires_login(:update, id: image.id, target_id: obs.id,
                                   target_type: "Observation")
      assert_redirected_to(permanent_observation_path(obs.id))
      assert(obs.reload.images.member?(image))
      assert_not_equal(updated_at, obs.updated_at)
    end

    def test_reuse_image_by_id
      obs = observations(:agaricus_campestris_obs)
      updated_at = obs.updated_at
      image = images(:commercial_inquiry_image)
      assert_not(obs.images.member?(image))
      params = {
        id: image.id.to_s,
        target_id: obs.id.to_s,
        target_type: "Observation"
      }
      owner = obs.user.login
      assert_not_equal("mary", owner)
      post_requires_login(:update, params, "mary")
      assert_redirected_to(permanent_observation_path(obs.id))
      assert_not(obs.reload.images.member?(image))

      login(owner)
      post(:update, params: params)
      assert_redirected_to(permanent_observation_path(obs.id))
      assert(obs.reload.images.member?(image))
      assert_not_equal(updated_at, obs.updated_at)
    end

    def test_reuse_image_for_observation_bad_image_id
      obs = observations(:agaricus_campestris_obs)
      params = { id: "bad_id", target_id: obs.id,
                 target_type: "Observation" }

      login(obs.user.login)
      post(:update, params: params)

      assert_flash(:runtime_image_reuse_invalid_id, id: params[:id])
      assert_unprocessable
      assert_select("form[data-turbo='true']")
    end

    def test_reuse_image_strip_gps_failed
      login("mary")
      obs = observations(:minimal_unknown_obs)
      img = images(:in_situ_image)
      obs.update_attribute(:gps_hidden, true)
      assert_false(img.gps_stripped)
      post(:update, params: { id: img.id, target_id: obs.id,
                              target_type: "Observation" })
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
      orig_file = img.full_filepath("orig")
      path = orig_file.sub(%r{/[^/]*$}, "")
      FileUtils.mkdir_p(path) unless File.directory?(path)
      FileUtils.cp(fixture, orig_file)

      post(:update, params: { id: img.id, target_id: obs.id,
                              target_type: "Observation" })
      assert_true(img.reload.gps_stripped)
      assert_not_equal(File.size(fixture),
                       File.size(img.full_filepath("orig")))
    end

    # A reflection's images mirror its source (#4214), so image reuse
    # works on its companion, as Edit does.
    def test_reuse_on_reflection_redirects_to_a_new_companion
      obs = reflection
      login(obs.user.login)

      get(:index, params: { target_id: obs.id, target_type: "Observation" })

      companion = reflection_companion(obs)
      assert_not_nil(companion, "a companion should have been created")
      assert_redirected_to(
        images_reuse_path(target_type: "Observation", target_id: companion.id)
      )
      assert_flash_success(:image_reuse_on_reflection_companion_created)
    end

    def test_reuse_on_reflection_uses_the_existing_companion
      obs = reflection
      companion = Observation::Companion.new(obs, obs.user).create
      login(obs.user.login)

      assert_no_difference("Observation.count") do
        get(:index, params: { target_id: obs.id,
                              target_type: "Observation" })
      end

      assert_redirected_to(
        images_reuse_path(target_type: "Observation", target_id: companion.id)
      )
      assert_flash_success(:image_reuse_on_reflection_companion_existing)
    end

    def test_attach_on_reflection_lands_on_the_companion
      obs = reflection
      image = images(:disconnected_coprinus_comatus_image)
      login(obs.user.login)

      post(:update, params: { id: image.id, target_id: obs.id,
                              target_type: "Observation" })

      companion = reflection_companion(obs)
      assert_redirected_to(permanent_observation_path(companion.id))
      assert_includes(companion.images, image)
      assert_not_includes(obs.reload.images, image)
    end

    def test_reuse_and_attach_report_companion_creation_failure
      obs = reflection
      login(obs.user.login)

      Observation::Companion.stub(:new, ->(*) { failing_companion }) do
        get(:index, params: { target_id: obs.id,
                              target_type: "Observation" })
        assert_flash_error
        assert_redirected_to(permanent_observation_path(id: obs.id))

        post(:update,
             params: { id: images(:in_situ_image).id, target_id: obs.id,
                       target_type: "Observation" })
        assert_flash_error
        assert_redirected_to(permanent_observation_path(id: obs.id))
      end
    end

    ##########################################################################
    # GlossaryTerm target

    def test_reuse_image_page_access_for_glossary_term
      glossary_term = glossary_terms(:conic_glossary_term)
      params = { target_id: glossary_term.id, target_type: "GlossaryTerm" }
      requires_login(:index, params)
      assert_form_action(action: :update, id: PLACEHOLDER_ID,
                         target_type: "GlossaryTerm",
                         target_id: glossary_term.id)
    end

    def test_reuse_image_page_access_for_glossary_term__all_images
      glossary_term = glossary_terms(:conic_glossary_term)
      params = { all_users: 1, target_id: glossary_term.id,
                 target_type: "GlossaryTerm" }
      requires_login(:index, params)

      assert_select("option", { text: :image_reuse_just_yours.l },
                    "Toggle should have an option to show only the " \
                    "user's images.")
    end

    # layout_count: 1 forces 2 pages out of mary's 2 image fixtures.
    def test_reuse_image_page_shows_pagination_for_glossary_term
      glossary_term = glossary_terms(:conic_glossary_term)
      mary.update!(layout_count: 1)

      login("mary")
      get(:index, params: { target_id: glossary_term.id,
                            target_type: "GlossaryTerm" })

      assert_select(".pagination_numbers a", { text: "Next" },
                    "Page with multiple pages of images to reuse " \
                    "should show a pagination nav")
    end

    def test_reuse_image_for_glossary_term_post
      glossary_term = glossary_terms(:conic_glossary_term)
      image = images(:commercial_inquiry_image)
      assert_not(glossary_term.images.member?(image))
      params = {
        id: image.id.to_s,
        target_id: glossary_term.id.to_s,
        target_type: "GlossaryTerm"
      }
      login("mary")
      post(:update, params: params)
      assert_redirected_to(glossary_term_path(glossary_term.id))
      assert(glossary_term.reload.images.member?(image))
    end

    def test_reuse_image_for_glossary_term_post_without_thumbnail
      glossary_term = glossary_terms(:convex_glossary_term)
      image = images(:commercial_inquiry_image)
      assert_empty(glossary_term.images)
      assert_nil(glossary_term.thumb_image)
      params = {
        id: image.id.to_s,
        target_id: glossary_term.id.to_s,
        target_type: "GlossaryTerm"
      }
      login("mary")
      post(:update, params: params)
      assert_redirected_to(glossary_term_path(glossary_term.id))
      assert(glossary_term.reload.images.member?(image))
      assert_objs_equal(image, glossary_term.thumb_image)
    end

    def test_reuse_image_for_glossary_term_add_image_fails
      glossary_term = glossary_terms(:convex_glossary_term)
      image = images(:commercial_inquiry_image)
      assert_empty(glossary_term.images)
      assert_nil(glossary_term.thumb_image)
      params = {
        id: image.id.to_s,
        target_id: glossary_term.id.to_s,
        target_type: "GlossaryTerm"
      }
      login("mary")
      get(:index, params: { target_id: glossary_term.id.to_s,
                            target_type: "GlossaryTerm" })
      assert_form_action(action: :update, id: PLACEHOLDER_ID,
                         target_type: "GlossaryTerm",
                         target_id: glossary_term.id)

      # force glossary_term.add_image to fail. `find_or_goto_index`
      # uses `GlossaryTerm.show_includes.find_by` — stub the class +
      # find_by so the controller sees our save-mocked instance.
      glossary_term.stub(:save, false) do
        GlossaryTerm.stub(:show_includes, GlossaryTerm) do
          GlossaryTerm.stub(:find_by, glossary_term) do
            post(:update, params: params)
          end
        end
      end
      assert_flash_error
      assert_unprocessable
      assert_select("form[data-turbo='true']")
    end

    def test_reuse_image_for_glossary_bad_image_id
      glossary_term = glossary_terms(:conic_glossary_term)
      params = { id: "111", target_id: glossary_term.id,
                 target_type: "GlossaryTerm" }

      post_requires_login(:update, params)

      assert_flash(:runtime_image_reuse_invalid_id, id: params[:id])
      assert_unprocessable
      assert_select("form[data-turbo='true']")
    end

    ##########################################################################
    # User (profile) target

    def test_reuse_user_profile_image_as_itself
      user = users(:rolf)
      assert(img = user.image, "Test needs User fixture with profile image")

      login(user.login)
      params = { id: img.id, target_id: rolf.id, target_type: "User" }
      post(:update, params: params)

      assert_equal(img, user.image)
      assert_flash(:runtime_no_changes)
    end

    def test_attach_image_to_another_users_profile_redirects
      user = users(:rolf)
      other_user = users(:mary)
      image = images(:commercial_inquiry_image)

      login(user.login)
      post(:update, params: { id: image.id, target_id: other_user.id,
                              target_type: "User" })

      assert_redirected_to(edit_account_profile_path)
      assert_not_equal(image, other_user.reload.image)
    end

    def test_reuse_image_for_user_page_access
      requires_login(:index, target_type: "User", target_id: rolf.id)
      assert_select("body.reuse__index")
      assert_form_action(action: :update, id: PLACEHOLDER_ID,
                         target_type: "User", target_id: rolf.id)
    end

    # layout_count: 1 forces 2 pages out of mary's 2 image fixtures.
    def test_reuse_image_page_shows_pagination_for_user
      mary.update!(layout_count: 1)

      login("mary")
      get(:index, params: { target_type: "User", target_id: mary.id })

      assert_select(".pagination_numbers a", { text: "Next" },
                    "Page with multiple pages of images to reuse " \
                    "should show a pagination nav")
    end

    def test_update_image_for_user_via_img_id
      image = images(:commercial_inquiry_image)
      params = { id: image.id.to_s, target_id: rolf.id,
                 target_type: "User" }
      post_requires_login(:update, params)
      assert_redirected_to(user_path(rolf.id))
      assert_equal(rolf.id, session[:user_id])
      assert_equal(image.id, rolf.reload.image_id)
    end

    def test_attach_invalid_img_id_renders_reuse_with_flash
      login("rolf")
      post(:update, params: { id: "99999999", target_id: rolf.id,
                              target_type: "User" })

      assert_unprocessable
      assert_flash_error(:runtime_image_reuse_invalid_id, id: "99999999")
      assert_select("form[data-turbo='true']")
    end

    private

    def reflection
      obs = observations(:imported_inat_obs)
      obs.update_column(:reflected_at, Time.zone.now)
      obs
    end

    def reflection_companion(obs)
      occurrence = obs.reload.occurrence
      return nil unless occurrence

      occurrence.observations.where.not(id: obs.id).first
    end

    def failing_companion
      invalid = Observation.new
      invalid.errors.add(:base, :occurrence_max_observations_exceeded,
                         max: Occurrence::MAX_OBSERVATIONS)
      Struct.new(:record) do
        def existing = nil

        def create
          raise(ActiveRecord::RecordInvalid.new(record))
        end
      end.new(invalid)
    end
  end
end

# frozen_string_literal: true

require("test_helper")

# tests of Images controller
module Observations
  class ImagesControllerTest < FunctionalTestCase
    def test_reuse_image_page_access
      obs = observations(:agaricus_campestris_obs)
      params = { id: obs.id }
      assert_equal("rolf", obs.user.login)

      logout
      get(:new, params: params)
      assert_response(:login, "No user: ")

      login("mary", "testpassword")
      get(:new, params: params)

      # assert_redirected_to(%r{/#{obs.id}$})
      assert_redirected_to(controller: :observations, action: :show,
                           id: obs.id)

      login("rolf", "testpassword")
      get(:new, params: params)

      assert_response(:success)
      assert_form_action(action: :create, id: obs.id, q: get_query_param)
    end

    def test_reuse_image_page_access__all_images
      obs = observations(:agaricus_campestris_obs)
      params = { all_users: 1, mode: "observation", id: obs.id }

      login(obs.user.login)
      get(:new, params: params)

      assert_form_action(action: :create, id: obs.id, q: get_query_param)
      assert_select("a", { text: :image_reuse_just_yours.l },
                    "Form should have a link to show only the user's images.")
    end

    # Test reusing an image by id number. Same as the next test (?!)
    def test_add_image_to_obs_by_id
      obs = observations(:coprinus_comatus_obs)
      updated_at = obs.updated_at
      image = images(:disconnected_coprinus_comatus_image)
      assert_not(obs.images.member?(image))
      post_requires_login(:create, id: obs.id, img_id: image.id)
      assert_redirected_to(controller: :observations, action: :show,
                           id: obs.id)
      assert(obs.reload.images.member?(image))
      assert(updated_at != obs.updated_at)
    end

    def test_reuse_image_by_id
      obs = observations(:agaricus_campestris_obs)
      updated_at = obs.updated_at
      image = images(:commercial_inquiry_image)
      assert_not(obs.images.member?(image))
      params = {
        id: obs.id.to_s,
        img_id: image.id.to_s
      }
      owner = obs.user.login
      assert_not_equal("mary", owner)
      post_requires_login(:create, params, "mary")
      # assert_template(controller: :observations, action: :show)
      assert_redirected_to(controller: :observations, action: :show,
                           id: obs.id)
      assert_not(obs.reload.images.member?(image))

      login(owner)
      post(:create, params: params)
      # assert_template(controller: :observations, action: :show)
      assert_redirected_to(controller: :observations, action: :show,
                           id: obs.id)
      assert(obs.reload.images.member?(image))
      assert(updated_at != obs.updated_at)
    end

    def test_reuse_image_for_observation_bad_image_id
      obs = observations(:agaricus_campestris_obs)
      params = { id: obs.id, img_id: "bad_id" }

      login(obs.user.login)
      post(:create, params: params)

      assert_flash_text(:runtime_image_reuse_invalid_id.t(id: params[:img_id]))
    end

    def test_reuse_image_strip_gps_failed
      login("mary")
      obs = observations(:minimal_unknown_obs)
      img = images(:in_situ_image)
      obs.update_attribute(:gps_hidden, true)
      assert_false(img.gps_stripped)
      post(:create, params: { id: obs.id, img_id: img.id })
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

      post(:create, params: { id: obs.id, img_id: img.id })
      assert_true(img.reload.gps_stripped)
      assert_not_equal(File.size(fixture),
                       File.size(img.local_file_name("orig")))
    end

    def test_remove_images_page_access
      obs = observations(:coprinus_comatus_obs)
      params = { id: obs.id }
      assert_equal("rolf", obs.user.login)
      requires_user(
        :edit,
        { controller: :observations, action: :show, id: obs.id },
        params
      )
      assert_form_action(action: :update, id: obs.id, q: get_query_param)
    end

    def test_remove_images
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
      put_requires_login(:update, params, "mary")
      assert_redirected_to(controller: :observations, action: :show)
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
      put(:update, params: params)
      assert_redirected_to(controller: :observations, action: :show)
      # Observation gets downgraded to 1 point because it no longer has images.
      # assert_equal(1, mary.reload.contribution)
      assert_equal(10, mary.reload.contribution)
      assert_not(obs.reload.images.member?(keep))
      assert_nil(obs.thumb_image_id)
    end

    def test_remove_images_2
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
      put(:update, params: params)

      assert_empty(obs.reload.images)
    end
  end
end

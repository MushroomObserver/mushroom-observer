# frozen_string_literal: true

require "test_helper"

# test importing iNaturalist Observations to Mushroom Observer
module Observations
  class InatImportsControllerTest < FunctionalTestCase
    INAT_OBS_REQUEST_PREFIX = "https://api.inaturalist.org/v1/observations?"
    INAT_OBS_REQUEST_POSTFIX = "&order=desc&order_by=created_at&only_id=false"

    def test_new_inat_import
      login(users(:rolf).login)
      get(:new)

      assert_response(:success)
      assert_form_action(action: :create)
      assert_select("input#inat_ids", true,
                    "Form needs a field for inputting iNat ids")
    end

    def test_create_public_import_imageless_obs
      # See test/inat/README_INAT_FIXTURES.md
      inat_response_body =
        File.read("test/inat/evernia_no_photos.txt")
      inat_id = InatObs.new(inat_response_body).inat_id
      params = { inat_ids: inat_id }

      WebMock.stub_request(
        :get,
        "#{INAT_OBS_REQUEST_PREFIX}id=#{inat_id}#{INAT_OBS_REQUEST_POSTFIX}"
      ).to_return(body: inat_response_body)

      login

      assert_difference("Observation.count", 1, "Failed to create Obs") do
        put(:create, params: params)
      end

      obs = Observation.order(created_at: :asc).last
      assert_not_nil(obs.rss_log)
      assert_redirected_to(observations_path)

      assert_equal("mo_inat_import", obs.source)
      assert_equal(inat_id, obs.inat_id)

      assert(obs.comments.any?, "Imported iNat should have >= 1 Comment")
    end

    def test_create_public_import_obs_with_photo
      skip("Under Construction")
      # See test/inat/README_INAT_FIXTURES.md
      inat_response_body =
        File.read("test/inat/tremella_mesenterica.txt")
      inat_obs_data = InatObs.new(inat_response_body)
      inat_obs_id = inat_obs_data.inat_id
      inat_obs_photo = InatObsPhoto.new(
        inat_obs_data.obs[:observation_photos].first
      )
      # inat_obs = InatObs.new(inat_response_body)
      # inat_id = InatObs.new(inat_response_body).inat_id
      params = { inat_ids: inat_obs_id }
      user = users(:rolf)

      # stub the iNat API request
      WebMock.stub_request(
        :get,
        "#{INAT_OBS_REQUEST_PREFIX}id=#{inat_obs_id}#{INAT_OBS_REQUEST_POSTFIX}"
      ).to_return(body: inat_response_body)

      # stub the aws request for the photo
      WebMock.stub_request(
        :get,
        inat_obs_photo.url
      ).to_return(body: Rails.root.join("test/images/test_image.jpg").read)

      login(user.login)
      # TODO: fix stubbed method when InatImportsController fixes its APIKey
      APIKey.stub(:first, api_keys(:rolfs_mo_app_api_key)) do
        assert_difference("Observation.count", 1, "Failed to create Obs") do
          put(:create, params: params)
        end
      end

      obs = Observation.order(created_at: :asc).last
      assert_not_nil(obs.rss_log)
      assert_redirected_to(observations_path)
    end

    def test_create_import_plant
      # See test/inat/README_INAT_FIXTURES.md
      inat_response_body =
        File.read("test/inat/ceanothus_cordulatus.txt")
      inat_id = InatObs.new(inat_response_body).inat_id
      params = { inat_ids: inat_id }

      WebMock.stub_request(
        :get,
        "#{INAT_OBS_REQUEST_PREFIX}id=#{inat_id}#{INAT_OBS_REQUEST_POSTFIX}"
      ).to_return(body: inat_response_body)

      login

      assert_no_difference(
        "Observation.count", "Should not import iNat Plant observations"
      ) do
        put(:create, params: params)
      end

      assert_flash_text(:inat_taxon_not_importable.l(id: inat_id))
    end

    def test_create_inat_import_too_many_ids
      user = users(:rolf)
      params = { inat_ids: "12345 6789" }

      login(user.login)
      put(:create, params: params)

      assert_flash_text(:inat_not_single_id.l)
      assert_form_action(action: :create)
    end

    def test_create_inat_import_bad_inat_id
      user = users(:rolf)
      id = "badID"
      params = { inat_ids: id }

      login(user.login)
      put(:create, params: params)

      assert_flash_text(:runtime_illegal_inat_id.l(id: id))
      assert_form_action(action: :create)
    end
  end
end

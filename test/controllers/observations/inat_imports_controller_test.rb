# frozen_string_literal: true

require "test_helper"

# test importing iNaturalist Observations to Mushroom Observer
module Observations
  class InatImportsControllerTest < FunctionalTestCase
    def test_new_inat_import
      login(users(:rolf).login)
      get(:new)

      assert_response(:success)
      assert_form_action(action: :create)
      assert_select("input#inat_ids", true,
                    "Form needs a field for inputting iNat ids")
    end

    def test_create_simple_public_import
      # fixture created from iNat api for observation 213508767
      # See test/fixtures/inat/README_INAT_FIXTURES.md
      inat_response_body =
        File.read("test/fixtures/inat/tremella_mesenterica.txt")
      inat_id = "213508767"
      params = { inat_ids: inat_id }

      WebMock.stub_request(
        :get,
        "https://api.inaturalist.org/v1" \
        "/observations?id=#{inat_id}" \
        "&order=desc&order_by=created_at&only_id=false"
      ).to_return(body: inat_response_body)

      login

      assert_difference("Observation.count", 1, "Failed to create Obs") do
        put(:create, params: params)
      end

      obs = Observation.order(created_at: :asc).last
      assert_not_nil(obs.rss_log)
      assert_redirected_to(observations_path)
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

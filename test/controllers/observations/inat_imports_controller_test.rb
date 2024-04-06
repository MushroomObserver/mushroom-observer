# frozen_string_literal: true

require "test_helper"

# test importing iNaturalist Observations to Mushroom Observer
module Observations
  class InatImportsControllerTest < FunctionalTestCase
    def setup
      @inats = YAML.load_file("test/fixtures/inat.yaml", aliases: true).
               deep_symbolize_keys
    end

    def test_new_inat_import
      login(users(:rolf).login)
      get(:new)

      assert_response(:success)
      assert_form_action(action: :create)
      assert_select("input#inat_ids", true,
                    "Form needs a field for inputting iNat ids")
    end

    def test_create_inat_import
      inat_obs = @inats[:somion_unicolor]
      inat_id = inat_obs[:inat_id].to_s
      user = users(inat_obs[:user])
      params = { inat_ids: inat_id }

      path = "test/fixtures/inat/one_obs_public.txt"
      body = File.read(path)
      WebMock.stub_request(
        :get,
        "https://api.inaturalist.org/v1" \
        "/observations?id=#{inat_id}" \
        "&order=desc&order_by=created_at&only_id=false"
      ).to_return(body: body)

      login(user.login)
      put(:create, params: params)

      assert_response(:success)
      # TODO: Fixme this assert redirected to? Observation create
      # assert params?
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

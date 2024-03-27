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
                    "Form need a field for inputting iNat ids")
    end

    def test_create_inat_import
      user = users(:rolf)
      inat_id = 123_456_789
      params = { ids: [inat_id] }

      login(user.login)
      put(:create, params: params)

      assert_response(:success)
    end

    def test_create_inat_import_bad_inat_id
      user = users(:rolf)
      inat_id = "badID"
      params = { inat_ids: [inat_id] }

      login(user.login)
      put(:create, params: params)

      assert_flash_warning("Missing flash warning about illegal iNat id")
    end
  end
end

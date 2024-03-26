# frozen_string_literal: true

require "test_helper"

# test importing iNaturalist Observations to Mushroom Observer
module Observations
  class InatImportsControllerTest < FunctionalTestCase
    def test_new_inat_import
      user = users(:rolf)
      inat_id = 123_456_789
      params = { ids: [inat_id] }

      login(user.login)
      get(:new, params: params)

      assert_response(:success)
    end
  end
end

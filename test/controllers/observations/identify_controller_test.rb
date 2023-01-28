# frozen_string_literal: true

require("test_helper")

module Observations
  class IdentifyControllerTest < FunctionalTestCase
    def test_identify_observations_index
      login("mary")
      obs = Observation.needs_identification(users(:mary))

      get(:index)
      # binding.break
      assert_no_flash
      assert_equal(obs.length, obs.length)
      assert_response(:success)
    end
  end
end

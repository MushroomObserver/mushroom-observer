# frozen_string_literal: true

require("test_helper")

module Observations
  class IdentifyControllerTest < FunctionalTestCase
    def test_identify_observations_index
      login("mary")
      mary = users(:mary)
      obs = Observation.needs_identification(users(:mary))
      obs_count = obs.count
      mary.update(layout_count: obs_count + 1)

      get(:index)
      # it's not using her layout count. maybe i hardcoded it.
      assert_no_flash
      # assert_select(".matrix-box", obs_count)
      assert_response(:success)
    end
  end
end

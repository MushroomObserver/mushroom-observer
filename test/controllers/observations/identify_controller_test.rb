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
      assert_no_flash
      assert_select(".matrix-box", obs_count)
      assert_response(:success)

      # make a query, and test that the obs scope filters appropriately

      # mark some observations as reviewed and check the new obs_count
      # On the site, this happens via JS, so directly update the obs

      # vote on an unconfident naming and check the new obs_count
      # On the site, this happens via JS, but there should be a cast vote button
    end
  end
end

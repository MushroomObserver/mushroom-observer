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
      cal_obs = Observation.needs_identification(users(:mary)).
                in_region("California, USA")
      # remember the original count, will change
      cal_obs_count = cal_obs.count
      Query.lookup_and_save(:Observation, :pattern_search,
                            pattern: "California, USA")
      get(:index, params: { q: QueryRecord.last.id.alphabetize })
      assert_no_flash
      assert_select(".matrix-box", cal_obs_count)

      # mark five observations as reviewed and check the new obs_count
      # On the site, this happens via JS, so directly update the obs_view
      # First we have to create the ov, does not exist yet
      done_with_these = cal_obs.take(5).pluck(:id).each do |id|
        ObservationView.create({ observation_id: id,
                                 user_id: users(:mary).id,
                                 reviewed: true })
      end
      done_with_these.each do |id|
        assert_equal(
          true,
          ObservationView.find_by(observation_id: id,
                                  user_id: users(:mary).id).reviewed
        )
      end

      get(:index, params: { q: QueryRecord.last.id.alphabetize })
      assert_no_flash
      assert_select(".matrix-box", cal_obs_count - 5)

      # vote on an unconfident naming and check the new obs_count
      # On the site, this happens via JS, but there should be a cast vote button
    end
  end
end

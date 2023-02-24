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

      # Vote on the first unconfident naming and check the new obs_count
      # On the site, this happens via JS, so we'll do it directly
      new_cal_obs = Observation.needs_identification(users(:mary)).
                    in_region("California, USA")
      # Have to check for an actual naming, because some obs have no namings,
      # and obs.name_id.present? doesn't necessarily mean there's a naming
      not_confident = new_cal_obs.where(vote_cache: ..0)
      with_naming = not_confident.each_with_index do |no_conf, i|
        break i if no_conf.namings&.first&.id
      end
      vote_on_obs = not_confident[with_naming]
      vote_on_obs.change_vote(vote_on_obs.namings.first, 1)

      get(:index, params: { q: QueryRecord.last.id.alphabetize })
      assert_no_flash
      assert_select(".matrix-box", cal_obs_count - 6)
    end
  end
end

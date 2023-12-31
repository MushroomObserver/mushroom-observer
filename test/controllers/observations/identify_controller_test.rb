# frozen_string_literal: true

require("test_helper")

module Observations
  class IdentifyControllerTest < FunctionalTestCase
    # NOTE: This is more like an integration test, but we can't write one of
    # those yet, without a JS runtime like Capybara
    def test_identify_observations_index
      login("mary")
      mary = users(:mary)
      # First make sure the index is showing everything.
      obs = Observation.needs_id_for_user(users(:mary))
      obs_count = obs.count
      mary.update(layout_count: obs_count + 1)

      query = Query.lookup_and_save(:Observation, :needs_id)
      assert_equal(query.num_results, obs_count)
      get(:index)
      assert_no_flash
      assert_select(".matrix-box", obs_count)
      assert_response(:success)

      # CLADE
      # make a query, and test that the query results match obs scope
      aga_obs = Observation.needs_id_for_user(mary).in_clade("Agaricales")
      query = Query.lookup_and_save(:Observation, :needs_id,
                                    in_clade: "Agaricales")

      # # get(:index, params: { q: QueryRecord.last.id.alphabetize })
      assert_equal(query.num_results, aga_obs.count)
      get(:index,
          params: { filter: { type: :clade, term: "Agaricales" } })
      assert_no_flash
      assert_select(".matrix-box", aga_obs.count)

      bol_obs = Observation.needs_id_for_user(mary).in_clade("Boletus")
      query = Query.lookup_and_save(:Observation, :needs_id,
                                    in_clade: "Boletus")
      assert_equal(query.num_results, bol_obs.count)

      # REGION
      # make a query, and test that the query results match obs scope
      # start with continent
      sam_obs = Observation.needs_id_for_user(mary).in_region("South America")
      query = Query.lookup_and_save(:Observation, :needs_id,
                                    in_region: "South America")
      assert_equal(query.num_results, sam_obs.count)

      cal_obs = Observation.needs_id_for_user(mary).in_region("California, USA")
      # remember the original count, will change
      cal_obs_count = cal_obs.count
      query = Query.lookup_and_save(:Observation, :needs_id,
                                    in_region: "California, USA")
      assert_equal(query.num_results, cal_obs_count)

      get(:index,
          params: { filter: { type: :region, term: "California, USA" } })
      assert_no_flash
      assert_select(".matrix-box", cal_obs_count)

      # mark five observations as reviewed and check the new obs_count
      # On the site, this happens via JS, so directly update the obs_view
      # First we have to create the ov, does not exist yet
      done_with_these = cal_obs.take(5).pluck(:id).each do |id|
        ObservationView.create({ observation_id: id,
                                 user_id: mary.id,
                                 reviewed: true })
      end
      done_with_these.each do |id|
        assert_equal(
          true,
          ObservationView.find_by(observation_id: id,
                                  user_id: mary.id).reviewed
        )
      end

      # get(:index, params: { q: QueryRecord.last.id.alphabetize })
      get(:index,
          params: { filter: { type: :region, term: "California, USA" } })
      assert_no_flash
      assert_select(".matrix-box", cal_obs_count - 5)

      # Vote on the first unconfident naming and check the new obs_count
      # On the site, this happens via JS, so we'll do it directly
      new_cal_obs = Observation.needs_id_for_user(mary).
                    in_region("California, USA")
      # Have to check for an actual naming, because some obs have no namings,
      # and obs.name_id.present? doesn't necessarily mean there's a naming
      not_confident = new_cal_obs.where(vote_cache: ..0)
      with_naming = not_confident.each_with_index do |no_conf, i|
        break i if no_conf.namings&.first&.id
      end
      vote_on_obs = not_confident[with_naming]
      consensus = ::Observation::NamingConsensus.new(vote_on_obs)
      consensus.change_vote(vote_on_obs.namings.first, 1)

      # get(:index, params: { q: QueryRecord.last.id.alphabetize })
      get(:index,
          params: { filter: { type: :region, term: "California, USA" } })
      assert_no_flash
      assert_select(".matrix-box", cal_obs_count - 6)

      # clear the query and be sure we get everything,
      # ...minus the ones marked reviewed and the one voted on
      get(:index, params: { commit: :CLEAR.l })
      assert_no_flash
      assert_select(".matrix-box", obs_count - 6)
    end
  end
end

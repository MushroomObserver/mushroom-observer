# frozen_string_literal: true

require("test_helper")

module Observations
  class MapsControllerTest < FunctionalTestCase
    def test_map_observations
      login
      get(:index)
      assert_template(:index)
    end

    def test_map_observation_hidden_gps
      obs = observations(:unknown_with_lat_long)
      login("rolf") # a user who does not own obs
      get(:show, params: { id: obs.id })
      assert_true(assigns(:observations).map(&:lat).map(&:to_s).join.
                                         include?("34.1622"))
      assert_true(assigns(:observations).map(&:long).map(&:to_s).join.
                                         include?("118.3521"))

      obs.update(gps_hidden: true)
      get(:show, params: { id: obs.id })
      assert_false(assigns(:observations).map(&:lat).map(&:to_s).join.
                                          include?("34.1622"))
      assert_false(assigns(:observations).map(&:long).map(&:to_s).join.
                                          include?("118.3521"))
    end

    def test_map_observations_hidden_gps
      obs = observations(:unknown_with_lat_long)
      query = Query.lookup_and_save(:Observation, :by_user, user: mary.id)
      assert(query.result_ids.include?(obs.id))

      login("rolf") # a user who does not own obs
      get(:index, params: { q: query.id.alphabetize })
      assert_true(assigns(:observations).map(&:lat).map(&:to_s).join.
                                         include?("34.1622"))
      assert_true(assigns(:observations).map(&:long).map(&:to_s).join.
                                         include?("118.3521"))

      obs.update(gps_hidden: true)
      get(:index, params: { q: query.id.alphabetize })
      assert_false(assigns(:observations).map(&:lat).map(&:to_s).join.
                                          include?("34.1622"))
      assert_false(assigns(:observations).map(&:long).map(&:to_s).join.
                                          include?("118.3521"))
    end
  end
end

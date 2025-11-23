# frozen_string_literal: true

require("test_helper")

module Observations
  class MapsControllerTest < FunctionalTestCase
    def test_map_observations
      login
      get(:index)
      assert_template(:index)
    end

    # Tests validation of nested params passed into Query
    def test_map_obs_by_pattern_user_in_box
      login
      pattern = "user%3A123+north%3A42.3201+south%3A36.8186+" \
                "east%3A-119.19399999999999+west%3A-123.27900000000001"
      get(:index, params: { pattern: })
    end

    # NOTE: the assigns(:observations) are Mappable::MinimalObservations!
    def test_map_observation_unhidden_gps
      obs = observations(:unknown_with_lat_lng)

      login("rolf") # a user who does not own obs
      get(:show, params: { id: obs.id })

      assert_includes(
        assigns(:observations).map { |o| o.lat.to_s }.join, obs.lat.to_s,
        "User map of unhidden observation should include geoloc with lat"
      )
      assert_includes(
        assigns(:observations).map { |o| o.lng.to_s }.join, obs.lng.to_s,
        "User map of unhidden observation should include geoloc with lng"
      )
    end

    # NOTE: the assigns(:observations) are Mappable::MinimalObservations!
    def test_map_observation_hidden_gps_owner
      obs = observations(:trusted_hidden)

      login(obs.user.login)
      get(:show, params: { id: obs.id })

      assert_includes(
        assigns(:observations).map { |o| o.lat.to_s }.join, obs.lat.to_s,
        "Owner map of hidden observation should include geoloc with lat"
      )
      assert_includes(
        assigns(:observations).map { |o| o.lng.to_s }.join, obs.lng.to_s,
        "Owner map of hidden observation should include geoloc with lng"
      )
    end

    # NOTE: the assigns(:observations) are Mappable::MinimalObservations!
    def test_map_observation_hidden_gps_non_owner
      obs = observations(:trusted_hidden)

      login("rolf")
      get(:show, params: { id: obs.id })

      assert_not_includes(
        assigns(:observations).map { |o| o.lat.to_s }.join, obs.lat.to_s,
        "Non-owner map of hidden observation should not include geoloc with lat"
      )
      assert_not_includes(
        assigns(:observations).map { |o| o.lng.to_s }.join, obs.lng.to_s,
        "Non-owner map of hidden observation should not include geoloc with lng"
      )
    end
  end
end

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

    # Lazy-loaded single-observation popup used by the cluster map (#4159).
    # Exercises the `popup` action end-to-end: builds a MinimalObservation
    # + MapSet and renders `mapset_info_window` as a JSON `html` payload.
    def test_map_observation_popup
      obs = observations(:unknown_with_lat_lng)
      login
      get(:popup, params: { id: obs.id })

      assert_response(:success)
      json = JSON.parse(@response.body)
      assert_kind_of(String, json["html"],
                     "popup JSON should carry a rendered html string")
      assert_includes(json["html"], obs.name.text_name,
                      "popup html should render the observation's name")
      assert_includes(
        json["html"], "/observations/#{obs.id}",
        "popup html should link back to the observation show page"
      )
    end

    # With a `q[...]` param present, the action must convert
    # ActionController::Parameters to a plain Hash before handing it
    # to URL helpers inside `mapset_info_window`. Regression guard
    # against "unable to convert unpermitted parameters to hash".
    def test_map_observation_popup_with_query_param
      obs = observations(:unknown_with_lat_lng)
      login
      get(:popup,
          params: { id: obs.id, q: { model: "Observation" } })

      assert_response(:success)
      json = JSON.parse(@response.body)
      assert_match(
        /q(%5B|\[)model(%5D|\])/, json["html"],
        "popup links should carry the q[model] query param through"
      )
    end

    # JSON format on the index action is the refetch path used by the
    # client-side viewport listener (#4159). Covers
    # map_refetch_payload end-to-end.
    def test_map_observations_json_refetch_payload
      login
      get(:index, format: :json)

      assert_response(:success)
      json = JSON.parse(@response.body)
      %w[collection capped loaded total cap].each do |key|
        assert(json.key?(key),
               "JSON refetch payload should include #{key}")
      end
      assert_kind_of(Hash, json["collection"])
      assert_equal(MapHelper::CLUSTER_MAX_OBJECTS, json["cap"])
    end

    # When the result set exceeds the cap, the controller runs the
    # extra COUNT(*) query to populate `total` for the banner. We
    # exercise that branch by temporarily shrinking the cap so any
    # multi-obs fixture set overflows.
    def test_map_observations_json_capped_runs_total_count
      login
      with_cluster_max_objects(1) do
        get(:index, format: :json)
      end

      assert_response(:success)
      json = JSON.parse(@response.body)
      assert(json["capped"],
             "cap of 1 should produce a capped response")
      assert_equal(1, json["loaded"],
                   "loaded count should be clamped to the cap")
      assert_equal(1, json["cap"])
      assert_operator(
        json["total"], :>, json["loaded"],
        "capped payload should surface the true total from " \
        "count_observations_matching_query"
      )
    end

    private

    # Swap `MapHelper::CLUSTER_MAX_OBJECTS` for the duration of a
    # block. `remove_const` before `const_set` avoids the
    # "already-initialized constant" warning.
    def with_cluster_max_objects(value)
      original = MapHelper::CLUSTER_MAX_OBJECTS
      MapHelper.send(:remove_const, :CLUSTER_MAX_OBJECTS)
      MapHelper.const_set(:CLUSTER_MAX_OBJECTS, value)
      yield
    ensure
      MapHelper.send(:remove_const, :CLUSTER_MAX_OBJECTS)
      MapHelper.const_set(:CLUSTER_MAX_OBJECTS, original)
    end
  end
end

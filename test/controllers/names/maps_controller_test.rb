# frozen_string_literal: true

require("test_helper")

module Names
  class MapsControllerTest < FunctionalTestCase
    include ObjectLinkHelper

    # ----------------------------
    #  Maps
    # ----------------------------

    # We do not offer maps for multiple names. You have to pass a name ID.
    # name with Observations that have Locations
    def test_map_names
      login
      get(:show, params: { id: names(:agaricus_campestris).id })
      assert_template("names/maps/show")
    end

    # name with Observations that don't have Locations
    def test_map_names_no_loc
      login
      get(:show, params: { id: names(:coprinus_comatus).id })
      assert_template("names/maps/show")
    end

    # name with no Observations
    def test_map_names_no_obs
      login
      get(:show, params: { id: names(:conocybe_filaris).id })
      assert_template("names/maps/show")
    end

    # Regression: the Occurrence Map for a name must not inherit a
    # spatial filter (`in_box`) from the session's stored query —
    # that's what made #4139 sticky even after the URL stopped
    # carrying `q=…`. Session-stored prior query had `in_box`; the
    # Occurrence Map for a name should still render the full
    # distribution.
    def test_show_ignores_in_box_from_session_query
      login
      stale_query = Query.lookup_and_save(
        :Observation,
        in_box: { north: 40, south: 30, east: -70, west: -80 }
      )
      @request.session[:query_record] = stale_query.id

      get(:show, params: { id: names(:agaricus_campestris).id })

      assert_template("names/maps/show")
      assert_not(assigns(:query).params.key?(:in_box),
                 "Names map query must not inherit in_box from the " \
                 "session — should be a fresh name-only query (#4139)")
      assert_equal(
        { lookup: [names(:agaricus_campestris).id] },
        assigns(:query).params[:names],
        "Names map query should be scoped to just the requested name"
      )
    end

    # When the URL itself carries an in_box (e.g. the JS viewport
    # refetch), the controller honors it. This is the only path that
    # should put in_box on the query.
    def test_show_honors_in_box_from_url
      login
      get(:show, params: {
            id: names(:agaricus_campestris).id,
            q: { in_box: { north: 40, south: 30, east: -70, west: -80 } }
          })

      assert_template("names/maps/show")
      assert_equal(
        { north: 40.0, south: 30.0, east: -70.0, west: -80.0 },
        assigns(:query).params[:in_box].transform_values(&:to_f).symbolize_keys,
        "URL-supplied in_box should pass through to the query"
      )
    end
  end
end

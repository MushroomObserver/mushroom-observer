# frozen_string_literal: true

require("test_helper")

module Geo
  class ElevationsControllerTest < IntegrationTestCase
    def test_get_elevation_with_query_string
      stub_open_elevation_api
      login

      get(geo_elevation_path, params: { locations: "39.7391,-104.9847" })

      assert_response(:success)
      json = response.parsed_body
      assert_equal(1, json["results"].length)
      assert_equal(1617.0, json["results"][0]["elevation"])
    end

    def test_post_elevation_with_json_body
      stub_open_elevation_api
      login

      post(
        geo_elevation_path,
        params: { locations: [{ lat: 39.7391, lng: -104.9847 }] }.to_json,
        headers: { "Content-Type" => "application/json" }
      )

      assert_response(:success)
      json = response.parsed_body
      assert_equal(1, json["results"].length)
    end

    def test_returns_error_when_no_locations
      login

      get(geo_elevation_path)

      assert_response(:bad_request)
      json = response.parsed_body
      assert_equal("No locations provided", json["error"])
    end

    def test_handles_upstream_api_error
      stub_request(:post, Geo::ElevationsController::OPEN_ELEVATION_URL).
        to_return(status: 500, body: "Internal Server Error")
      login

      get(geo_elevation_path, params: { locations: "39.7391,-104.9847" })

      assert_response(:success) # We still return 200 with error in body
      json = response.parsed_body
      assert_equal("Upstream API error", json["error"])
    end

    private

    def stub_open_elevation_api
      stub_request(:post, Geo::ElevationsController::OPEN_ELEVATION_URL).
        to_return(
          status: 200,
          body: {
            results: [
              { latitude: 39.7391, longitude: -104.9847, elevation: 1617.0 }
            ]
          }.to_json,
          headers: { "Content-Type" => "application/json" }
        )
    end
  end
end

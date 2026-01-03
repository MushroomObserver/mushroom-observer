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

    # Live API test - skipped by default, run manually to verify grid sampling.
    # Tests the Mt. Hood area bounding box with grids of increasing density.
    # Run with: bin/rails test test/controllers/geo/elevations_controller_test.rb \
    #           -n test_grid_sampling_density_live_api
    def test_grid_sampling_density_live_api
      skip("Live API test - run with LIVE_API=1") unless ENV["LIVE_API"]

      # Mt. Hood area - good test case for mountainous terrain
      box = { north: 45.5203, south: 44.8101, east: -121.3586, west: -122.2301 }

      [9, 12, 15, 18, 21].each do |size|
        points = generate_grid(box, size)
        elevations = fetch_live_elevations(points)

        if elevations.any?
          high = elevations.max
          low = elevations.min
          puts "#{size}x#{size} (#{points.size} pts): " \
               "High=#{high}m, Low=#{low}m, Range=#{high - low}m"
        else
          puts "#{size}x#{size} (#{points.size} pts): API error or empty response"
        end

        sleep(2) # Be nice to the API
      end

      assert(true, "Grid sampling experiment complete")
    end

    private

    def generate_grid(box, size)
      points = []
      lat_step = (box[:north] - box[:south]) / (size - 1).to_f
      lng_step = (box[:east] - box[:west]) / (size - 1).to_f

      size.times do |i|
        size.times do |j|
          points << {
            lat: box[:south] + (i * lat_step),
            lng: box[:west] + (j * lng_step)
          }
        end
      end
      points
    end

    def fetch_live_elevations(points)
      uri = URI(Geo::ElevationsController::OPEN_ELEVATION_URL)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http.open_timeout = 10
      http.read_timeout = 60

      # Open-Elevation expects { locations: [{latitude:, longitude:}, ...] }
      formatted = points.map { |p| { latitude: p[:lat], longitude: p[:lng] } }

      req = Net::HTTP::Post.new(uri)
      req["Content-Type"] = "application/json"
      req.body = { locations: formatted }.to_json

      response = http.request(req)
      result = JSON.parse(response.body)

      unless result["results"]
        puts "API Error: #{result}"
        return []
      end

      result["results"].map { |r| r["elevation"] }
    end

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

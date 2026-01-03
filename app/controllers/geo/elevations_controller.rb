# frozen_string_literal: true

module Geo
  # Proxies elevation requests to Open-Elevation API.
  # This provides a stable interface and avoids exposing external API details.
  #
  # Usage:
  #   GET /geo/elevation?locations=39.7391,-104.9847|40.0,-105.0
  #   POST /geo/elevation with JSON body: { "locations": [...] }
  #
  class ElevationsController < BaseController
    OPEN_ELEVATION_URL = "https://api.open-elevation.com/api/v1/lookup"

    # GET /geo/elevation?locations=lat1,lng1|lat2,lng2
    # POST /geo/elevation with JSON body
    def show
      locations = parse_locations
      return render_error("No locations provided") if locations.blank?

      result = fetch_elevations(locations)
      render(json: result)
    rescue StandardError => e
      Rails.logger.error("Elevation API error: #{e.message}")
      render_error("Failed to fetch elevations", status: :service_unavailable)
    end

    private

    def parse_locations
      if request.post? && request.content_type&.include?("application/json")
        parse_json_locations
      else
        parse_query_locations
      end
    end

    # Parse locations from query string: "lat1,lng1|lat2,lng2"
    def parse_query_locations
      return [] if params[:locations].blank?

      params[:locations].split("|").map do |pair|
        lat, lng = pair.split(",").map(&:to_f)
        { "latitude" => lat, "longitude" => lng }
      end
    end

    # Parse locations from JSON body: [{"lat": 1, "lng": 2}, ...]
    def parse_json_locations
      body = JSON.parse(request.body.read)
      locations = body["locations"] || []
      locations.map do |loc|
        {
          "latitude" => loc["lat"] || loc["latitude"],
          "longitude" => loc["lng"] || loc["longitude"]
        }
      end
    rescue JSON::ParserError
      []
    end

    def fetch_elevations(locations)
      response = elevation_http_client.request(elevation_request(locations))
      parse_elevation_response(response)
    end

    def elevation_http_client
      uri = URI(OPEN_ELEVATION_URL)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http.open_timeout = 5
      http.read_timeout = 10
      http
    end

    def elevation_request(locations)
      req = Net::HTTP::Post.new(URI(OPEN_ELEVATION_URL))
      req["Content-Type"] = "application/json"
      req.body = { locations: locations }.to_json
      req
    end

    def parse_elevation_response(response)
      if response.is_a?(Net::HTTPSuccess)
        JSON.parse(response.body)
      else
        { "error" => "Upstream API error", "status" => response.code }
      end
    end
  end
end

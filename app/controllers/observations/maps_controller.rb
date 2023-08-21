# frozen_string_literal: true

module Observations
  class MapsController < ApplicationController
    before_action :login_required

    # Map results of a search or index.
    def index
      show and return if params[:id].present?

      @query = find_or_create_query(:Observation)
      apply_content_filters(@query)
      @query = restrict_query_to_box(@query)

      find_locations_matching_observations

      render(template: "observations/maps/index")
    end

    # Show map of one observation by id.
    def show
      pass_query_params
      obs = find_or_goto_index(Observation, params[:id].to_s)
      return unless obs

      @observations = [
        MinimalMapObservation.new(obs.id, obs.public_lat, obs.public_long,
                                  obs.location)
      ]
      render(template: "observations/maps/index")
    end

    private

    def find_locations_matching_observations
      locations = {}
      columns = %w[id lat long gps_hidden location_id].map do |x|
        "observations.#{x}"
      end
      args = {
        select: columns.join(", "),
        where: "observations.lat IS NOT NULL OR " \
                "observations.location_id IS NOT NULL"
      }
      @observations =
        @query.select_rows(args).map do |id, lat, long, gps_hidden, loc_id|
          locations[loc_id.to_i] = nil if loc_id.present?
          lat = long = nil if gps_hidden == 1
          MinimalMapObservation.new(id, lat, long, loc_id)
        end

      eager_load_corresponding_locations(locations) unless locations.empty?
    end

    def eager_load_corresponding_locations(locations)
      @locations = Location.where(id: locations.keys).map do |loc|
        locations[loc.id] = MinimalMapLocation.new(
          loc.id, loc.name, loc.north, loc.south, loc.east, loc.west
        )
      end

      @observations.each do |obs|
        obs.location = locations[obs.location_id] if obs.location_id
      end
    end
  end
end

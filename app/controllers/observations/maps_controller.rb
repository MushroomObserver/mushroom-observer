# frozen_string_literal: true

module Observations
  class MapsController < ApplicationController
    before_action :login_required

    # Map results of a search or index.
    def index
      show and return if params[:id].present?

      @query = find_or_create_query(:Observation)
      apply_content_filters(@query)

      find_locations_matching_observations
    end

    # Show map of one observation by id.
    def show
      pass_query_params
      @observation = find_or_goto_index(Observation, params[:id].to_s)
      return unless @observation

      @observations = [
        Mappable::MinimalObservation.new(id: @observation.id,
                                         lat: @observation.public_lat,
                                         lng: @observation.public_lng,
                                         location: @observation.location,
                                         location_id: @observation.location_id)
      ]
    end

    private

    def find_locations_matching_observations
      locations = {}
      columns = %w[id lat lng gps_hidden location_id].map do |x|
        "observations.#{x}"
      end
      args = {
        select: columns.join(", "),
        where: "observations.lat IS NOT NULL OR " \
                "observations.location_id IS NOT NULL",
        limit: 10_000
      }
      @observations =
        @query.select_all(args).map do |obs|
          obs.symbolize_keys!
          # Setting this to nil is a flag to look up the location. Because we
          # selected obs attributes not instances, we can't call `obs.location`
          # and we shouldn't anyway. Getting the Locations in bulk is quicker.
          locations[obs[:location_id].to_i] = nil if obs[:location_id].present?
          obs[:lat] = obs[:lng] = nil if obs[:gps_hidden] == 1
          Mappable::MinimalObservation.new(obs.except(:gps_hidden))
        end

      eager_load_corresponding_locations(locations) unless locations.empty?
    end

    def eager_load_corresponding_locations(locations)
      @locations = Location.where(id: locations.keys).
                   select(:id, :name, :north, :south, :east, :west).map do |loc|
        locations[loc.id] = Mappable::MinimalLocation.new(
          loc.attributes.symbolize_keys
        )
      end

      @observations.each do |obs|
        obs.location = locations[obs.location_id] if obs.location_id
      end
    end
  end
end

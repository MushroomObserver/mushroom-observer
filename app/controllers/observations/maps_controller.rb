# frozen_string_literal: true

module Observations
  class MapsController < ApplicationController
    before_action :login_required

    def controller_model_name
      "Observation"
    end

    # Map results of a search or index.
    def index
      show and return if params[:id].present?

      @query = find_or_create_query(:Observation)
      @any_content_filters_applied = check_if_preference_filters_applied
      find_locations_matching_observations
    end

    # Show map of one observation by id.
    def show
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
      location_ids = Set[]
      columns = [:id, :lat, :lng, :gps_hidden, :location_id].map do |col|
        Observation[col]
      end
      minimal_obs_query = @query.scope.
                          where(Observation[:lat].not_eq(nil).
                                or(Observation[:location_id].not_eq(nil))).
                          limit(MO.query_max_array).select(*columns)
      @observations = minimal_obs_query.map do |obs|
        obs = obs.attributes.symbolize_keys!
        # Adding this to the set is a flag to look up the location. Because we
        # selected obs attributes not instances, we can't call `obs.location`
        # and we shouldn't anyway. Getting the Locations in bulk is quicker.
        location_ids << obs[:location_id].to_i if obs[:location_id].present?
        obs[:lat] = obs[:lng] = nil if obs[:gps_hidden].to_s.to_boolean == true
        Mappable::MinimalObservation.new(obs.except(:gps_hidden))
      end

      eager_load_related_locations(location_ids) unless location_ids.empty?
    end

    def eager_load_related_locations(location_ids)
      locations = {}
      @locations = Location.where(id: location_ids).
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

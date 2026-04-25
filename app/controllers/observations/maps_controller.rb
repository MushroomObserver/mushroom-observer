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

      if permission?(@observation)
        lat = @observation.lat
        lng = @observation.lng
      else
        lat = @observation.public_lat
        lng = @observation.public_lng
      end

      @observations = [
        Mappable::MinimalObservation.new(
          id: @observation.id,
          lat: lat, lng: lng,
          location: @observation.location,
          location_id: @observation.location_id,
          name_id: @observation.name_id,
          text_name: @observation.name&.text_name,
          display_name: @observation.name&.display_name,
          when: @observation.when,
          vote_cache: @observation.vote_cache,
          thumb_image_id: @observation.thumb_image_id
        )
      ]
    end

    private

    def find_locations_matching_observations
      location_ids = Set[]
      name_ids = Set[]
      minimal_obs_query = @query.scope.
                          where(Observation[:lat].not_eq(nil).
                                or(Observation[:location_id].not_eq(nil))).
                          limit(MO.query_max_array).
                          select(*minimal_obs_columns)
      @observations = minimal_obs_query.map do |obs|
        obs = obs.attributes.symbolize_keys!
        location_ids << obs[:location_id].to_i if obs[:location_id].present?
        name_ids << obs[:name_id].to_i if obs[:name_id].present?
        obs[:lat] = obs[:lng] = nil if obs[:gps_hidden].to_s.to_boolean == true
        Mappable::MinimalObservation.new(obs.except(:gps_hidden))
      end

      eager_load_related_locations(location_ids) unless location_ids.empty?
      eager_load_related_names(name_ids) unless name_ids.empty?
    end

    # Columns selected for minimal-observation map rendering. `name_id`,
    # `when`, `vote_cache`, and `thumb_image_id` are used by popup
    # content for #4131.
    def minimal_obs_columns
      [:id, :lat, :lng, :gps_hidden, :location_id,
       :name_id, :when, :vote_cache, :thumb_image_id].
        map { |c| Observation[c] }
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

    def eager_load_related_names(name_ids)
      rows = Name.where(id: name_ids).
             pluck(:id, :text_name, :display_name).
             to_h { |id, text, display| [id, [text, display]] }
      @observations.each do |obs|
        next unless (pair = rows[obs.name_id])

        obs.text_name = pair[0]
        obs.display_name = pair[1]
      end
    end
  end
end

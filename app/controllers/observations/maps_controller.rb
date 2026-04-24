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

      respond_to do |format|
        format.html
        format.json { render(json: map_refetch_payload) }
      end
    end

    # Rendered caption HTML for a single observation — used by the
    # client to lazy-load popup content when the user clicks a marker
    # on a clustered map (#4159). Sending pre-rendered captions for
    # every obs in the bulk payload was the dominant refetch cost; on
    # click we only need one.
    def popup
      observation = find_or_goto_index(Observation, params[:id].to_s)
      return unless observation

      lat = permission?(observation) ? observation.lat : observation.public_lat
      lng = permission?(observation) ? observation.lng : observation.public_lng
      minimal = Mappable::MinimalObservation.new(
        id: observation.id,
        lat: lat, lng: lng,
        location: observation.location,
        location_id: observation.location_id,
        name_id: observation.name_id,
        text_name: observation.name&.text_name,
        display_name: observation.name&.display_name,
        when: observation.when,
        vote_cache: observation.vote_cache,
        thumb_image_id: observation.thumb_image_id
      )
      set = Mappable::MapSet.new([minimal])
      # params[:q] arrives as ActionController::Parameters; URL helpers
      # inside mapset_info_window reject unpermitted parameters, so
      # convert to a plain Hash before passing through.
      args = { query_param: params[:q].presence&.to_unsafe_h }
      render(json: { html: view_context.mapset_info_window(set, args) })
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

    # Payload for the JSON refetch on map zoom/pan. The client rebuilds
    # all overlays from the returned collection and updates the cap
    # banner visibility based on `capped`.
    def map_refetch_payload
      args = { query_param: q_param(@query), map_type: "info" }
      {
        collection: view_context.clustered_collection(@observations, args),
        capped: @observations_capped,
        loaded: @observations_loaded_count,
        total: @observations_total_count,
        cap: @observations_cap
      }
    end

    # Capped at MapHelper::CLUSTER_MAX_OBJECTS so the client never has
    # to cluster more points than it can handle. Fetches `cap + 1`
    # rows so we can detect overflow cheaply (no separate COUNT
    # query); the extra row is trimmed before building the minimal
    # observations. A running refetch on viewport change (handled
    # client-side) pulls the in-viewport subset back under the cap
    # when the user zooms or pans.
    def find_locations_matching_observations
      cap = MapHelper::CLUSTER_MAX_OBJECTS
      rows = @query.scope.
             where(Observation[:lat].not_eq(nil).
                   or(Observation[:location_id].not_eq(nil))).
             limit(cap + 1).
             select(*minimal_obs_columns).to_a

      @observations_capped = rows.size > cap
      rows = rows.first(cap) if @observations_capped
      @observations_loaded_count = rows.size
      @observations_cap = cap
      # Total is only surfaced in the cap banner, so skip the extra
      # COUNT(*) when the initial fetch already has everything.
      @observations_total_count = if @observations_capped
                                    count_observations_matching_query
                                  else
                                    @observations_loaded_count
                                  end

      location_ids = Set[]
      name_ids = Set[]
      @observations = rows.map do |row|
        build_minimal_observation(row, location_ids, name_ids)
      end

      eager_load_related_locations(location_ids) unless location_ids.empty?
      eager_load_related_names(name_ids) unless name_ids.empty?
    end

    # COUNT(*) of the same WHERE used for the banner's "of <total>".
    # Separate query — the fetch above already ran under LIMIT, so its
    # row count can't double as a total.
    def count_observations_matching_query
      @query.scope.
        where(Observation[:lat].not_eq(nil).
              or(Observation[:location_id].not_eq(nil))).
        count
    end

    def build_minimal_observation(row, location_ids, name_ids)
      obs = row.attributes.symbolize_keys!
      location_ids << obs[:location_id].to_i if obs[:location_id].present?
      name_ids << obs[:name_id].to_i if obs[:name_id].present?
      obs[:lat] = obs[:lng] = nil if obs[:gps_hidden].to_s.to_boolean == true
      Mappable::MinimalObservation.new(obs.except(:gps_hidden))
    end

    # Columns selected for minimal-observation map rendering. `name_id`,
    # `when`, `vote_cache`, `thumb_image_id` are used by popup content
    # (#4131). `gps_dubious` lets the map layer skip recomputing the
    # per-obs predicate used for point-vs-box positioning (#4159).
    def minimal_obs_columns
      [:id, :lat, :lng, :gps_hidden, :gps_dubious, :location_id,
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

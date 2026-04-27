# frozen_string_literal: true

module Observations
  class MapsController < ApplicationController
    include(ClusteredObservationMap)

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
  end
end

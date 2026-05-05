# frozen_string_literal: true

#  map::                         Show distribution map.
module Names
  class MapsController < ApplicationController
    include(ClusteredObservationMap)

    before_action :login_required

    def controller_model_name
      "Name"
    end

    # Draw a map of all the locations where this name has been observed.
    # Uses the dynamic-clustering pipeline shared with
    # `Observations::MapsController#index` (#4159).
    def show
      @name = find_or_goto_index(Name, params[:id].to_s)
      return unless @name

      @query = build_name_distribution_query
      update_stored_query(@query)
      @any_content_filters_applied = check_if_preference_filters_applied
      find_locations_matching_observations

      respond_to do |format|
        format.html
        format.json { render(json: map_refetch_payload) }
      end
    end

    private

    # Build a fresh query for this name's distribution. Bypasses the
    # session-stored query that `find_or_create_query` would otherwise
    # merge in — that merge silently inherited an `in_box` (or other
    # filter) from a previous map navigation, restricting the
    # Occurrence Map to a stale bbox (#4139).
    #
    # If the URL itself carries an `in_box` (e.g. the JS viewport
    # refetch sending the current map bounds), honor that — but
    # nothing else from `params[:q]` or the session.
    def build_name_distribution_query
      args = { names: { lookup: @name.id } }
      box = in_box_param_hash
      args[:in_box] = box if box.present?
      create_query(:Observation, args)
    end

    def in_box_param_hash
      raw = params[:q]
      return nil unless raw

      hash = raw.respond_to?(:to_unsafe_h) ? raw.to_unsafe_h : raw
      if hash.respond_to?(:with_indifferent_access)
        hash = hash.with_indifferent_access
      end
      hash[:in_box]
    end
  end
end

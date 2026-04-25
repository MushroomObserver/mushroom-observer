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

      @query = find_or_create_query(:Observation, names: { lookup: @name.id })
      @any_content_filters_applied = check_if_preference_filters_applied
      find_locations_matching_observations

      respond_to do |format|
        format.html
        format.json { render(json: map_refetch_payload) }
      end
    end
  end
end

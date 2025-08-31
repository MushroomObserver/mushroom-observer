# frozen_string_literal: true

#  map::                         Show distribution map.
module Names
  class MapsController < ApplicationController
    before_action :login_required

    def controller_model_name
      "Name"
    end

    # Draw a map of all the locations where this name has been observed.
    def show
      @name = find_or_goto_index(Name, params[:id].to_s)
      return unless @name

      @query = find_or_create_query(:Observation, names: { lookup: @name.id })
      @any_content_filters_applied = check_if_preference_filters_applied
      @observations = @query.scope.limit(MO.query_max_array).
                      includes(:location).
                      select { |o| o.lat || o.location }
    end
  end
end

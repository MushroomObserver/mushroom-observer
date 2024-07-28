# frozen_string_literal: true

#  map::                         Show distribution map.
module Names
  class MapsController < ApplicationController
    before_action :login_required

    # Draw a map of all the locations where this name has been observed.
    def show
      pass_query_params
      @name = find_or_goto_index(Name, params[:id].to_s)
      return unless @name

      @query = create_query(:Observation, :all, names: @name.id)
      apply_content_filters(@query)
      @observations = @query.results(include: :location, limit: 10_000).
                      select { |o| o.lat || o.location }
    end
  end
end

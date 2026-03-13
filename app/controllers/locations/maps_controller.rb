# frozen_string_literal: true

# map_locations
module Locations
  class MapsController < ApplicationController
    before_action :login_required

    def controller_model_name
      "Location"
    end

    # Map results of a search or index of Locations.
    def show
      @query = find_or_create_query(:Location)
      @any_content_filters_applied = check_if_preference_filters_applied
      columns = [:id, :name, :north, :south, :east, :west].map do |col|
        Location[col]
      end
      @locations = @query.scope.select(*columns).distinct.
                   limit(MO.query_max_array).map do |loc|
        Mappable::MinimalLocation.new(loc.attributes.symbolize_keys)
      end
    end
  end
end

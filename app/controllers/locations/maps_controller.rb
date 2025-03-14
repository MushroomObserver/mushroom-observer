# frozen_string_literal: true

# map_locations
module Locations
  class MapsController < ApplicationController
    before_action :login_required

    # Map results of a search or index of Locations.
    def show
      @query = find_or_create_query(:Location)
      @any_content_filters_applied = check_if_preference_filters_applied
      columns = %w[name north south east west].map { |x| "locations.#{x}" }
      args = { select: "DISTINCT(locations.id), #{columns.join(", ")}",
               limit: 10_000 }
      @locations = @query.select_all(args).map do |loc|
        Mappable::MinimalLocation.new(loc)
      end
    end
  end
end

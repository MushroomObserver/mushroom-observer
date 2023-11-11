# frozen_string_literal: true

# map_locations
module Locations
  class MapsController < ApplicationController
    before_action :login_required

    # Map results of a search or index.
    def show
      @query = find_or_create_query(:Location)

      apply_content_filters(@query)

      @query = restrict_query_to_box(@query)
      columns = %w[name north south east west].map { |x| "locations.#{x}" }
      args = { select: "DISTINCT(locations.id), #{columns.join(", ")}" }
      @locations = @query.select_rows(args).map do |id, *the_rest|
        Mappable::MinimalLocation.new(id, *the_rest)
      end
    end
  end
end

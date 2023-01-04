# frozen_string_literal: true

# map_locations
module Locations
  class MapsController < ApplicationController
    before_action :login_required
    before_action :disable_link_prefetching

  # Map results of a search or index.
  def map_locations
    @query = find_or_create_query(:Location)

    apply_content_filters(@query)

    @title = if @query.flavor == :all
               :map_locations_global_map.t
             else
               :map_locations_title.t(locations: @query.title)
             end
    @query = restrict_query_to_box(@query)
    @timer_start = Time.current
    columns = %w[name north south east west].map { |x| "locations.#{x}" }
    args = { select: "DISTINCT(locations.id), #{columns.join(", ")}" }
    @locations = @query.select_rows(args).map do |id, *the_rest|
      MinimalMapLocation.new(id, *the_rest)
    end
    @num_results = @locations.count
    @timer_end = Time.current
  end
  end
end

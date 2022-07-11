# frozen_string_literal: true

# see observations_controller.rb
module ObservationsController::Map
  # Map results of a search or index.
  # cop disabled per https://github.com/MushroomObserver/mushroom-observer/pull/1060#issuecomment-1179410808
  # rubocop:disable Metrics/MethodLength
  # rubocop:disable Metrics/AbcSize
  def map
    map_observation and return if params[:id].present?

    @query = find_or_create_query(:Observation)
    apply_content_filters(@query)
    @title = :map_locations_title.t(locations: @query.title)
    @query = restrict_query_to_box(@query)
    @timer_start = Time.current

    # Get matching observations.
    locations = {}
    columns = %w[id lat long gps_hidden location_id].map do |x|
      "observations.#{x}"
    end
    args = {
      select: columns.join(", "),
      where: "observations.lat IS NOT NULL OR " \
             "observations.location_id IS NOT NULL"
    }
    @observations = \
      @query.select_rows(args).map do |id, lat, long, gps_hidden, loc_id|
        locations[loc_id.to_i] = nil if loc_id.present?
        lat = long = nil if gps_hidden == 1
        MinimalMapObservation.new(id, lat, long, loc_id)
      end

    unless locations.empty?
      # Eager-load corresponding locations.
      @locations = Location.
                   where(id: locations.keys.sort).
                   pluck(:id, :name, :north, :south, :east, :west).
                   map do |id, *the_rest|
        locations[id] = MinimalMapLocation.new(id, *the_rest)
      end
      @observations.each do |obs|
        obs.location = locations[obs.location_id] if obs.location_id
      end
    end
    @num_results = @observations.count
    @timer_end = Time.current
  end
  # rubocop:enable Metrics/MethodLength
  # rubocop:enable Metrics/AbcSize

  # Show map of one observation by id.
  def map_observation
    pass_query_params
    obs = find_or_goto_index(Observation, params[:id].to_s)
    return unless obs

    @title = :map_observation_title.t(id: obs.id)
    @observations = [
      MinimalMapObservation.new(obs.id, obs.public_lat, obs.public_long,
                                obs.location)
    ]
    render(template: "observations/map")
  end
end

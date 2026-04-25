# frozen_string_literal: true

# Shared loader + JSON refetch payload for controllers that map a
# query of observations with the dynamic-clustering pipeline (#4159).
# Caller sets `@query` (an `::Query::Observations`-shaped query) before
# invoking `find_locations_matching_observations`. The concern then
# populates `@observations`, `@observations_capped`,
# `@observations_loaded_count`, `@observations_total_count`, and
# `@observations_cap` for the view + JSON paths to read.
#
# Used by `Observations::MapsController#index` and
# `Names::MapsController#show`.
module ClusteredObservationMap
  extend ActiveSupport::Concern

  private

  # Capped at MapHelper::CLUSTER_MAX_OBJECTS so the client never has
  # to cluster more points than it can handle. Fetches `cap + 1` rows
  # so we can detect overflow cheaply (no separate COUNT query); the
  # extra row is trimmed before building the minimal observations. A
  # client-side viewport refetch (also keyed off this cap) pulls the
  # in-viewport subset back under the cap when the user zooms or pans.
  def find_locations_matching_observations
    rows = capped_observation_rows
    record_observation_count_ivars(rows)
    build_minimal_observations_from_rows(rows)
  end

  def capped_observation_rows
    cap = MapHelper::CLUSTER_MAX_OBJECTS
    rows = mapped_observations_scope.limit(cap + 1).
           select(*minimal_obs_columns).to_a
    @observations_capped = rows.size > cap
    @observations_cap = cap
    @observations_capped ? rows.first(cap) : rows
  end

  # Total is only surfaced in the cap banner, so skip the extra
  # COUNT(*) when the initial fetch already has everything.
  def record_observation_count_ivars(rows)
    @observations_loaded_count = rows.size
    @observations_total_count = if @observations_capped
                                  count_observations_matching_query
                                else
                                  @observations_loaded_count
                                end
  end

  def build_minimal_observations_from_rows(rows)
    location_ids = Set[]
    name_ids = Set[]
    @observations = rows.map do |row|
      build_minimal_observation(row, location_ids, name_ids)
    end
    eager_load_related_locations(location_ids) unless location_ids.empty?
    eager_load_related_names(name_ids) unless name_ids.empty?
  end

  # Payload for the JSON refetch on map zoom/pan. The client rebuilds
  # all overlays from the returned collection and updates the cap
  # banner visibility based on `capped`.
  def map_refetch_payload
    args = { query_param: q_param(@query), map_type: "info" }
    {
      collection: view_context.clustered_collection(@observations, args),
      capped: @observations_capped,
      loaded: @observations_loaded_count,
      total: @observations_total_count,
      cap: @observations_cap
    }
  end

  # The base scope that the cap fetch and the total-count query both
  # run against. Pulled out so callers that need a different filter
  # (e.g. only obs with thumbnails) can override.
  def mapped_observations_scope
    @query.scope.
      where(Observation[:lat].not_eq(nil).
            or(Observation[:location_id].not_eq(nil)))
  end

  # COUNT(*) of the same WHERE used for the banner's "of <total>".
  # Separate query — the cap fetch already ran under LIMIT, so its
  # row count can't double as a total.
  def count_observations_matching_query
    mapped_observations_scope.count
  end

  def build_minimal_observation(row, location_ids, name_ids)
    obs = row.attributes.symbolize_keys!
    track_related_ids(obs, location_ids, name_ids)
    obs[:lat] = obs[:lng] = nil if obs[:gps_hidden].to_s.to_boolean == true
    Mappable::MinimalObservation.new(obs.except(:gps_hidden))
  end

  def track_related_ids(obs, location_ids, name_ids)
    location_ids << obs[:location_id].to_i if obs[:location_id].present?
    name_ids << obs[:name_id].to_i if obs[:name_id].present?
  end

  # Columns selected for minimal-observation map rendering. `name_id`,
  # `when`, `vote_cache`, `thumb_image_id` are used by popup content
  # (#4131). `gps_dubious` lets the map layer skip recomputing the
  # per-obs predicate used for point-vs-box positioning (#4159).
  def minimal_obs_columns
    [:id, :lat, :lng, :gps_hidden, :gps_dubious, :location_id,
     :name_id, :when, :vote_cache, :thumb_image_id].
      map { |c| Observation[c] }
  end

  def eager_load_related_locations(location_ids)
    locations = {}
    @locations = Location.where(id: location_ids).
                 select(:id, :name, :north, :south, :east, :west).map do |loc|
      locations[loc.id] = Mappable::MinimalLocation.new(
        loc.attributes.symbolize_keys
      )
    end

    @observations.each do |obs|
      obs.location = locations[obs.location_id] if obs.location_id
    end
  end

  def eager_load_related_names(name_ids)
    rows = Name.where(id: name_ids).
           pluck(:id, :text_name, :display_name).
           to_h { |id, text, display| [id, [text, display]] }
    @observations.each do |obs|
      next unless (pair = rows[obs.name_id])

      obs.text_name = pair[0]
      obs.display_name = pair[1]
    end
  end
end

# frozen_string_literal: true

#
#  = Clustered Map Collection Class
#
#  Parallel to CollapsibleCollectionOfObjects but WITHOUT geographic
#  bucketing — one MapSet per source object. Used when the caller
#  wants the client to cluster dynamically via
#  @googlemaps/markerclusterer (issue #4159).
#
#  Exposes the same `sets` / `extents` / `representative_points`
#  attributes so the existing JS collection consumer doesn't have to
#  branch on payload shape.
#

module Mappable
  class ClusteredCollection
    include Mappable::Collection
    include CoordinateFormat

    # Build a clustered collection directly from a list of mappable
    # objects (no geographic bucketing — one MapSet per object).
    # Used by both `Components::Map`'s render path and the controller's
    # JSON-refetch endpoint
    # (`ClusteredObservationMap#map_refetch_payload`), so the same
    # singleton-key / cluster-url shape is produced regardless of how
    # the collection was reached.
    #
    # @param objects [Array<Mappable>] the source objects.
    # @param query_param [Hash, nil] the current query's q_param —
    #   added as `?q=…` on every per-marker cluster URL so a click
    #   from the popup lands inside the same filtered query context.
    # @param user [User, nil] the viewer - decides postal/scientific
    #   location-name formatting (nil => postal default).
    def initialize(objects, query_param: nil, user: nil)
      @sets = {}
      routes = Rails.application.routes.url_helpers
      objects.each do |obj|
        @sets[singleton_key_for(obj)] = build_set(obj, query_param, routes,
                                                  user)
      end
      @extents = calc_extents
      @representative_points =
        [@extents.north_west, @extents.center, @extents.south_east]
    end

    private

    def build_set(obj, query_param, routes, user)
      set = MapSet.new([obj])
      set.color = set.compute_color
      set.glyph = set.compute_glyph
      set.border_style = set.compute_border_style
      set.title = mapset_title_for(set, user)
      # caption is intentionally omitted — the client lazy-loads it
      # from observations/maps#popup on marker click. Rendering N
      # thumbnail-bearing popups at bulk-fetch time dominated refetch
      # cost (#4159).
      set.cluster_name = cluster_label_for(obj, user)
      set.cluster_url = cluster_url_for(obj, query_param, routes)
      set.objects = nil
      set
    end

    # `MinimalObservation` IDs start at 1; Location objects share the
    # integer space but carry their own ids, so prefix to disambiguate.
    def singleton_key_for(obj)
      prefix = obj.respond_to?(:observation?) && obj.observation? ? "o" : "l"
      "#{prefix}#{obj.id}"
    end

    # Plain-text name grouping-key used by cluster popups — authors
    # are stripped by using the obs's `text_name` (fall back to the
    # stringified display_name for locations — only ::Observation /
    # ::Mappable::MinimalObservation expose `text_name`).
    def cluster_label_for(obj, user)
      return obj.text_name if obj.respond_to?(:text_name) &&
                              obj.text_name.present?

      obj.display_name(user).to_s
    end

    # Every object reaching `ClusteredCollection.new` is mappable
    # (`Mappable::BoxMethods#location?` plus `Observation#observation?`
    # / `MinimalObservation#observation?`), so the two branches are
    # exhaustive. `MapSet#init_objects_and_derive_extents` raises on
    # anything else, so this method never runs on an unmappable obj.
    def cluster_url_for(obj, query_param, routes)
      params = query_param ? { q: query_param } : {}
      if obj.observation?
        routes.observation_path(id: obj.id, params: params)
      else
        routes.location_path(id: obj.id, params: params)
      end
    end

    # Marker tooltip text. Mirrors the per-object branch in the
    # deleted `MapHelper#map_location_strings` — an obs with no
    # location but known lat/lng falls back to formatted coordinates
    # so the tooltip isn't blank (the GPS-only observation case).
    # Two-branch exhaustive: see `cluster_url_for`'s note.
    def mapset_title_for(set, user)
      first = set.objects.first
      if first.observation?
        observation_title_for(first, user)
      else
        first.display_name(user).to_s
      end
    end

    def observation_title_for(obs, user)
      return obs.location.display_name(user).to_s if obs.location

      return "" unless obs.lat

      "#{format_latitude(obs.lat)} #{format_longitude(obs.lng)}"
    end
  end
end

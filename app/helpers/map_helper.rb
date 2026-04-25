# frozen_string_literal: true

module MapHelper
  include MapLegendHelper
  include MapPopupHelper

  # Upper bound on points for client-side dynamic clustering
  # (issue #4159). The controller truncates at this cap and surfaces
  # a banner so the user knows to narrow by filter or by zooming in.
  # The client-side viewport refetch (also keyed off this cap) will
  # pull in the in-viewport subset when the user zooms/pans.
  CLUSTER_MAX_OBJECTS = 10_000

  # args could include query_param.
  # returns an array of mapsets, each suitable for a marker or box
  def make_map(objects: [], **args)
    nothing_to_map = args[:nothing_to_map] || :runtime_map_nothing_to_map.t
    objects = reject_unknown_locations(objects)
    return tag.div(nothing_to_map, class: "w-100") unless objects.any?

    map_args = build_map_args(objects, args, nothing_to_map)
    safe_join([map_html(map_args), map_legend(objects: objects)])
  end

  def reject_unknown_locations(objects)
    objects.reject do |obj|
      name = obj.respond_to?(:location) ? obj.location&.name : obj.name
      Location.is_unknown?(name)
    end
  end

  def build_map_args(objects, args, nothing_to_map)
    map_args = default_map_args.
               merge(args.except(:nothing_to_map, :clustering))
    add_collection_to_args(map_args, objects, args)
    map_args[:localization] = build_localization(nothing_to_map).to_json
    map_args
  end

  def default_map_args
    {
      map_div: "map_div",
      controller: "map",
      map_target: "mapDiv",
      map_type: "info",
      need_elevations_value: true,
      map_open: true,
      editable: false,
      controls: [:large_map, :map_type].to_json,
      location_format: User.current_location_format
    }
  end

  def add_collection_to_args(map_args, objects, args)
    if args[:clustering] && objects.size <= CLUSTER_MAX_OBJECTS
      map_args[:collection] = clustered_collection(objects, map_args).to_json
      map_args[:clustering] = true
    else
      map_args[:collection] = mappable_collection(objects, map_args).to_json
    end
  end

  def build_localization(nothing_to_map)
    {
      nothing_to_map: nothing_to_map,
      observations: :Observations.t,
      locations: :Locations.t,
      show_all: :show_all.t,
      map_all: :map_all.t,
      # Raw template — the client substitutes `[loaded]` / `[total]`
      # with the formatted counts on each refetch. We bypass `.t` to
      # skip textile processing (double-underscore placeholders would
      # be italicized, etc.). Banner text has no textile markup, so
      # sending the raw string preserves what the ERB-rendered
      # version produces (#4159).
      map_cap_banner: I18n.t(:map_cap_banner)
    }
  end

  # Clustering mode (issue #4159): skip server-side geographic
  # bucketing. Each mappable object becomes a singleton MapSet so the
  # client can feed every observation marker through
  # @googlemaps/markerclusterer and group them dynamically at zoom.
  #
  # Returns a shape compatible with CollapsibleCollectionOfObjects —
  # a `sets` hash plus the `extents` / `representative_points`
  # derived attributes — so the existing JS collection consumer
  # doesn't have to branch on payload shape.
  def clustered_collection(objects, args)
    sets = {}
    objects.each do |obj|
      set = Mappable::MapSet.new([obj])
      set.color = set.compute_color
      set.glyph = set.compute_glyph
      set.border_style = set.compute_border_style
      set.title = mapset_marker_title(set)
      # caption is intentionally omitted — the client lazy-loads it
      # from observations/maps#popup on marker click. Rendering N
      # thumbnail-bearing popups at bulk-fetch time dominated refetch
      # cost (#4159).
      set.cluster_name = cluster_object_label(obj)
      set.cluster_url = cluster_object_url(obj, args)
      set.objects = nil
      sets[singleton_key(obj)] = set
    end
    Mappable::ClusteredCollection.new(sets)
  end

  # Plain text name grouping-key used by cluster popups — authors are
  # stripped by using the obs's `text_name` (fall back to the stringified
  # display_name for locations / unexpected shapes).
  def cluster_object_label(obj)
    return obj.text_name if obj.respond_to?(:text_name) &&
                            obj.text_name.present?
    return obj.display_name.to_s if obj.respond_to?(:display_name)

    ""
  end

  def cluster_object_url(obj, args)
    params = args[:query_param] ? { q: args[:query_param] } : {}
    if obj.respond_to?(:observation?) && obj.observation?
      observation_path(id: obj.id, params: params)
    elsif obj.respond_to?(:location?) && obj.location?
      location_path(id: obj.id, params: params)
    else
      ""
    end
  end

  # Unique key per mappable object for the sets hash. MinimalObservation
  # IDs start at 1; Location objects share the integer space but
  # carry their own ids.
  def singleton_key(obj)
    prefix = obj.respond_to?(:observation?) && obj.observation? ? "o" : "l"
    "#{prefix}#{obj.id}"
  end

  # Returns a CollapsibleCollection of mapsets, containing all data necessary
  # for the JS map_controller to draw them on map.
  # Collection attributes are sets, extents, and representative_points.
  # Each collection.set either `is_marker` or `is_box`.
  #
  # Uses Mappable::CollapsibleCollection to aggregate the mappable objects
  # until they are down to a manageable max_number. Then, iterates over the
  # collection.sets array, each of which will become a Marker or Box.
  # Adds title and caption attributes to each, and removes objects. (The AR
  # objects in the mapset are needed for caption, but not for google.maps API.)
  #
  def mappable_collection(objects, args)
    collection = Mappable::CollapsibleCollectionOfObjects.new(objects)
    collection.sets.map do |_key, mapset|
      mapset.color = mapset.compute_color
      mapset.glyph = mapset.compute_glyph
      mapset.border_style = mapset.compute_border_style
      mapset.title = mapset_marker_title(mapset)
      mapset.caption = mapset_info_window(mapset, args)
      mapset.objects = nil # can't delete, it's part of the MapSet object
    end

    collection
  end

  def map_html(map_args)
    tag.div(class: "w-100 position-relative map-container") do
      tag.div(
        "",
        id: map_args[:map_div],
        class: "position-absolute w-100 h-100",
        data: map_args.except(:map_div)
      )
    end
  end

  # TEXT for title and info_window

  def mapset_marker_title(set)
    strings = map_location_strings(set.objects)
    result = if strings.length > 1
               "#{strings.length} #{:locations.t}"
             else
               strings.first
             end
    num_obs = set.observations.length
    if num_obs > 1 && num_obs != strings.length
      num_str = "#{num_obs} #{:observations.t}"
      result += if strings.length > 1
                  ", #{num_str}"
                else
                  " (#{num_str})"
                end
    end
    result
  end

  def map_location_strings(objects)
    objects.map do |obj|
      if obj.location?
        obj.display_name
      elsif obj.observation?
        if obj.location
          obj.location.display_name
        elsif obj.lat # Observations have the attr. `long`, not `lng`
          "#{format_latitude(obj.lat)} #{format_longitude(obj.lng)}"
        end
      end
    end.compact_blank.uniq
  end
end

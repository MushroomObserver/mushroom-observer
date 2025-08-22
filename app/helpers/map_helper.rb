# frozen_string_literal: true

module MapHelper
  # args could include query_param.
  # returns an array of mapsets, each suitable for a marker or box
  def make_map(objects: [], **args)
    nothing_to_map = args[:nothing_to_map] || :runtime_map_nothing_to_map.t
    # There's nothing to map if the location is unknown.
    objects = objects.reject do |obj|
      name = obj.respond_to?(:location) ? obj.location&.name : obj.name
      Location.is_unknown?(name)
    end
    return tag.div(nothing_to_map, class: "w-100") unless objects.any?

    default_args = {
      map_div: "map_div",
      controller: "map",
      map_target: "mapDiv",
      map_type: "info",
      map_open: true,
      editable: false,
      controls: [:large_map, :map_type].to_json,
      location_format: User.current_location_format # method has a default
    }
    map_args = default_args.merge(args.except(:nothing_to_map))
    map_args[:collection] = mappable_collection(objects, map_args).to_json
    map_args[:localization] = {
      nothing_to_map: nothing_to_map,
      observations: :Observations.t,
      locations: :Locations.t,
      show_all: :show_all.t,
      map_all: :map_all.t
    }.to_json
    map_html(map_args)
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
      mapset.title = mapset_marker_title(mapset)
      mapset.caption = mapset_info_window(mapset, args)
      mapset.objects = nil # can't delete, it's part of the MapSet object
    end

    collection
  end

  def map_html(map_args)
    tag.div(class: "w-100 position-relative",
            style: "padding-bottom: 66%;") do
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

  def mapset_info_window(set, args)
    lines = []
    observations = set.observations
    locations = set.underlying_locations
    lines << mapset_observation_header(set) if observations.length > 1
    lines << mapset_location_header(set) if locations.length > 1
    if observations.length == 1 && observations.first&.id
      lines << mapset_observation_link(observations.first, args)
    end
    if locations.length == 1 && locations.first&.id # obj maybe not saved yet
      lines << mapset_location_link(locations.first, args)
    end
    lines << mapset_coords(set)
    lines.safe_join(safe_br)
  end

  def mapset_observation_header(set)
    show, map = mapset_associated_links(set, :observation)
    map_point_text(:Observations.t, set.observations.length, show, map)
  end

  def mapset_location_header(set)
    show, map = mapset_associated_links(set, :location)
    map_point_text(:Locations.t, set.underlying_locations.length, show, map)
  end

  def map_point_text(label, count, show, map)
    label.html_safe << ": " << count.to_s << " (" << show << " | " << map << ")"
  end

  # Links to obs, locs or names within the current mapset, or maps of these
  def mapset_associated_links(set, type)
    return unless [:observation, :location, :name].include?(type)

    mapset_associated_links_for_type(set, type)
  end

  # Helper for the above
  def mapset_associated_links_for_type(set, type)
    query_type = type.to_s.camelize.to_sym
    path_helper = :"#{type.to_s.pluralize}_path"
    # We probably already have a query, from the index that got us here.
    # This will correctly merge the in_box param into the query.
    query = controller.
            find_or_create_query(query_type, in_box: mapset_box_params(set))
    # Add the query params to the link data for debugging.
    # Can remove when we start splatting query params in the URL.
    [link_to(:show_all.t, add_query_param(send(path_helper), query),
             data: query.params),
     link_to(:map_all.t, add_query_param(send(:"map_#{path_helper}"), query),
             data: query.params)]
  end

  def mapset_observation_link(obs, args)
    params = args[:query_param] ? { q: args[:query_param] } : {}
    link_to("#{:Observation.t} ##{obs.id}",
            observation_path(id: obs.id, params: params))
  end

  def mapset_location_link(loc, args)
    params = args[:query_param] ? { q: args[:query_param] } : {}
    link_to(loc.display_name.t, location_path(id: loc.id, params: params))
  end

  # These are query params for the links back to MO indexes, slightly enlarged
  def mapset_box_params(set)
    { north: tweak_up(set.north, 0.001, 90),
      south: tweak_down(set.south, 0.001, -90),
      east: tweak_up(set.east, 0.001, 180),
      west: tweak_down(set.west, 0.001, -180) }
  end

  def tweak_up(value, amount, max)
    [max, value.to_f + amount].min
  end

  def tweak_down(value, amount, min)
    [min, value.to_f - amount].max
  end

  # These are coords printed in text
  def mapset_coords(set)
    if set.is_point
      format_latitude(set.lat) + safe_nbsp + format_longitude(set.lng)
    else
      content_tag(:center,
                  format_latitude(set.north) + safe_br +
                  format_longitude(set.west) + safe_nbsp +
                  format_longitude(set.east) + safe_br +
                  format_latitude(set.south))
    end
  end

  def format_latitude(val)
    format_lxxxitude(val, "N", "S")
  end

  def format_longitude(val)
    format_lxxxitude(val, "E", "W")
  end

  def format_lxxxitude(val, dir1, dir2)
    deg = val.abs.round(4)
    "#{deg}°#{val.negative? ? dir2 : dir1}".html_safe
  end
end

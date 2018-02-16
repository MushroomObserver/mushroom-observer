module MapHelper
  require_dependency "map_collapsible"
  require_dependency "map_set"
  require_dependency "gmaps"

  def make_map(objects, args = {})
    args = provide_defaults(args,
                            map_div: "map_div",
                            controls: [:large_map, :map_type],
                            info_window: true)
    collection = CollapsibleCollectionOfMappableObjects.new(objects)
    gmap = init_map(args)
    if args[:zoom]
      gmap.center_zoom_init(collection.extents.center, args[:zoom])
    else
      gmap.center_zoom_on_points_init(*collection.representative_points)
    end
    for mapset in collection.mapsets
      draw_mapset(gmap, mapset, args)
    end
    gmap
  end

  def make_editable_map(object, args = {})
    args = provide_defaults(args,
                            editable: true,
                            info_window: false)
    gmap = make_map(object, args)
    gmap.event_init(gmap, "click", "function(e) { clickLatLng(e.latLng) }")
    gmap.event_init(gmap, "dblclick", "function(e) { dblClickLatLng(e.latLng) }")
    gmap
  end

  def make_thumbnail_map(objects, args = {})
    args = provide_defaults(args,
                            controls: [:small_map],
                            info_window: true,
                            zoom: 2)
    make_map(objects, args)
  end

  def provide_defaults(args, default_args)
    default_args.merge(args)
  end

  def init_map(args = {})
    gmap = GM::GMap.new(args[:map_div])
    gmap.control_init(args[:controls].to_boolean_hash)
    gmap
  end

  def finish_map(gmap)
    ensure_global_header_is_added
    html = gmap.to_html(no_script_tag: 1)
    js = javascript_tag(html)
    add_header(js)
  end

  def ensure_global_header_is_added
    unless @done_gmap_header_yet
      add_header(GM::GMap.header(host: MO.domain))
      @done_gmap_header_yet = true
    end
  end

  def draw_mapset(gmap, set, args = {})
    title = mapset_marker_title(set)
    marker = GM::GMarker.new(set.center,
                             draggable: args[:editable],
                             title: title)
    marker.info_window = mapset_info_window(set, args) if args[:info_window]
    if args[:editable]
      map_control_init(gmap, marker, args)
      map_box_control_init(gmap, set, args) if set.is_box?
    else
      gmap.overlay_init(marker)
    end
    draw_box_on_gmap(gmap, set, args) if set.is_box?
  end

  def draw_box_on_gmap(gmap, set, args)
    box = GM::GPolyline.new([
      set.north_west,
      set.north_east,
      set.south_east,
      set.south_west,
      set.north_west
    ], "#00ff88", 3, 1.0)
    if args[:editable]
      box_name = args[:box_name] || "mo_box"
      gmap.overlay_global_init(box, box_name)
    else
      gmap.overlay_init(box)
    end
  end

  def mapset_marker_title(set)
    result = ""
    strings = map_location_strings(set.objects)
    if strings.length > 1
      result = "#{strings.length} #{:locations.t}"
    else
      result = strings.first
    end
    num_obs = set.observations.length
    if num_obs > 1 && num_obs != strings.length
      num_str = "#{num_obs} #{:observations.t}"
      if strings.length > 1
        result += ", #{num_str}"
      else
        result += " (#{num_str})"
      end
    end
    result
  end

  def map_location_strings(objects)
    objects.map do |obj|
      if obj.is_location?
        obj.display_name
      elsif obj.is_observation?
        if obj.location
          obj.location.display_name
        elsif obj.lat
          "#{format_latitude(obj.lat)} #{format_longitude(obj.long)}"
        end
      end
    end.reject(&:blank?).uniq
  end

  def mapset_info_window(set, args)
    lines = []
    observations = set.observations
    locations = set.underlying_locations
    lines << mapset_observation_header(set, args) if observations.length > 1
    lines << mapset_location_header(set, args) if locations.length > 1
    lines << mapset_observation_link(observations.first, args) if observations.length == 1
    lines << mapset_location_link(locations.first, args) if locations.length == 1
    lines << mapset_coords(set)
    lines.safe_join(safe_br)
  end

  def mapset_observation_header(set, args)
    show, map = mapset_submap_links(set, args, :observation)
    map_point_text(:Observations.t, set.observations.length, show, map)
  end

  def mapset_location_header(set, args)
    show, map = mapset_submap_links(set, args, :location)
    map_point_text(:Locations.t, set.underlying_locations.length, show, map)
  end

  def map_point_text(label, count, show, map)
    label.html_safe << ": " << count.to_s << " (" << show << " | " << map << ")"
  end

  def mapset_submap_links(set, args, type)
    params = args[:query_params] || {}
    params = params.merge(controller: type.to_s.sub("observation", "observer"))
    params = params.merge(mapset_box_params(set))
    [link_to(:show_all.t, params.merge(action: "index_#{type}")),
     link_to(:map_all.t, params.merge(action: "map_#{type}s"))]
  end

  def mapset_observation_link(obs, args)
    link_to("#{:Observation.t} ##{obs.id}", controller: :observer, action: :show_observation,
                                            id: obs.id, params: args[:query_params] || {})
  end

  def mapset_location_link(loc, args)
    link_to(loc.display_name.t, controller: :location, action: :show_location,
                                id: loc.id, params: args[:query_params] || {})
  end

  def mapset_box_params(set)
    {
      north: set.north,
      south: set.south,
      east: set.east,
      west: set.west
    }
  end

  def mapset_coords(set)
    if set.is_point?
      format_latitude(set.lat) + safe_nbsp + format_longitude(set.long)
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
    "#{deg}°#{val < 0 ? dir2 : dir1}".html_safe
  end

  def map_control_init(gmap, marker, args, type = "ct")
    name = args[:marker_name] || "mo_marker"
    gmap.overlay_global_init(marker, name + "_" + type)
    gmap.event_init(marker, "dragend", "function(e) {
      dragEndLatLng(e.latLng, '#{type}')
    }")
  end

  def map_box_control_init(gmap, set, args)
    [
      [set.north_west, "nw"],
      [set.north_east, "ne"],
      [set.south_west, "sw"],
      [set.south_east, "se"]
    ].each do |point, type|
      marker = GM::GMarker.new(point, draggable: true)
      map_control_init(gmap, marker, args, type)
    end
  end
end

# encoding: utf-8
#
#  = Google Maps Helpers
#
#  make_map::     Create a GMap.
#  finish_map::   Render the actual HTML needed for the given GMap.
#
#  == Typical Usage
#
#    <%=
#      gmap = make_map(@locations)
#      # (can tweak gmap here)
#      finish_map(gmap)
#      gmap.div(:width => 400, :height => 400)
#    %>
#
##############################################################################

require_dependency 'map_collapsible'
require_dependency 'map_set'

module GM
  include Ym4r::GmPlugin
end

module ApplicationHelper::Map
  def make_map(objects, args={})
    args = provide_defaults(args,
      :map_div => 'map_div',
      :controls => [ :large_map, :map_type ],
      :info_window => true
    )
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
    return gmap
  end

  def make_editable_map(object, args={})
    args = provide_defaults(args,
      :editable => true,
      :info_window => false
    )
    gmap = make_map(object, args)
    gmap.event_init(gmap, 'click', 'function(overlay, latlng) {
      clickLatLng(latlng);
    }')
    gmap.event_init(gmap, 'dblclick', 'function(overlay, latlng) {
      dblClickLatLng(latlng);
    }')
    return gmap
  end

  def make_thumbnail_map(objects, args={})
    args = provide_defaults(args,
      :controls => [ :small_map ],
      :info_window => true,
      :zoom => 2
    )
    return make_map(objects, args)
  end

  def provide_defaults(args, default_args)
    default_args.merge(args)
  end

  def init_map(args={})
    gmap = GM::GMap.new(args[:map_div])
    gmap.control_init(args[:controls].to_boolean_hash)
    return gmap
  end

  def finish_map(gmap)
    ensure_global_header_is_added
    html = gmap.to_html(:no_script_tag => 1)
    js = javascript_tag(html)
    add_header(js)
  end

  def ensure_global_header_is_added
    if !@done_gmap_header_yet
      add_header(GM::GMap.header(:host => DOMAIN))
      @done_gmap_header_yet = true
    end
  end

  def draw_mapset(gmap, set, args={})
    title = mapset_marker_title(set)
    marker = GM::GMarker.new(set.center,
      :draggable => args[:editable],
      :title => title
    )
    if args[:info_window]
      marker.info_window = mapset_info_window(set, args)
    end
    if args[:editable]
      map_control_init(gmap, marker, args)
      map_box_control_init(gmap, set, args) if set.is_box?
    else
      gmap.overlay_init(marker)
    end
    if set.is_box?
      draw_box_on_gmap(gmap, set, args)
    end
  end

  def draw_box_on_gmap(gmap, set, args)
    box = GM::GPolyline.new([
      set.north_west,
      set.north_east,
      set.south_east,
      set.south_west,
      set.north_west,
    ], "#00ff88", 3, 1.0)
    if args[:editable]
      box_name = args[:box_name] || 'mo_box'
      gmap.overlay_global_init(box, box_name)
    else
      gmap.overlay_init(box)
    end
  end

  def mapset_marker_title(set)
    result = ''
    strings = map_location_strings(set.objects)
    if strings.length > 1
      result = "#{strings.length} #{:locations.t}"
    else
      result = strings.first
    end
    num_obs = set.observations.length
    if num_obs > 1 and num_obs != strings.length
      num_str = "#{num_obs} #{:observations.t}"
      if strings.length > 1
        result += ", #{num_str}"
      else
        result += " (#{num_str})"
      end
    end
    return result
  end

  def map_location_strings(objects)
    objects.map do |obj|
      if obj.is_a?(Location)
        obj.display_name
      elsif obj.is_a?(Observation)
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
    lines << mapset_observation_header(observations, args) if observations.length > 1
    lines << mapset_location_header(locations, args) if locations.length > 1
    lines << mapset_observation_link(observations.first, args) if observations.length == 1
    lines << mapset_location_link(locations.first, args) if locations.length == 1
    lines << mapset_coords(set)
    return lines.join('<br/>')
  end

  def mapset_observation_header(observations, args)
    query = Query.lookup(:Observation, :in_set, :ids => observations.map(&:id))
    show = link_to(:show_all.t, :controller => :observer, :action => :index_observation,
                   :params => query_params(query))
    map = link_to(:map_all.t, :controller => :observer, :action => :map_observations,
                  :params => query_params(query))
    return "#{:Observations.t}: #{observations.length} (#{show} | #{map})"
  end

  def mapset_location_header(locations, args)
    query = Query.lookup(:Location, :in_set, :ids => locations.map(&:id))
    show = link_to(:show_all.t, :controller => :location, :action => :index_location,
                   :params => query_params(query))
    map = link_to(:map_all.t, :controller => :location, :action => :map_locations,
                  :params => query_params(query))
    return "#{:Locations.t}: #{locations.length} (#{show} | #{map})"
  end

  def mapset_observation_link(obs, args)
    link_to(obs.unique_format_name.t, :controller => :observer, :action => :show_observation,
            :id => obs.id, :params => args[:query_params] || {})
  end

  def mapset_location_link(loc, args)
    link_to(loc.display_name.t, :controller => :location, :action => :show_location,
            :id => loc.id, :params => args[:query_params] || {})
  end

  def mapset_coords(set)
    if set.is_point?
      "#{format_latitude(set.lat)} #{format_longitude(set.long)}"
    else
      content_tag(:center,
        "#{format_latitude(set.north)}<br/>" +
        "#{format_longitude(set.west)} &nbsp; #{format_longitude(set.east)}<br/>" +
        "#{format_latitude(set.south)}"
      )
    end
  end

  def format_latitude(val)
    format_lxxxitude(val, 'N', 'S')
  end

  def format_longitude(val)
    format_lxxxitude(val, 'E', 'W')
  end

  def format_lxxxitude(val, dir1, dir2)
    deg = val.abs.round(4)
    return "#{deg}°#{val < 0 ? dir2 : dir1}"

    # sec = (val.abs * 3600).round
    # min = (sec / 60.0).truncate
    # deg = (min / 60.0).truncate
    # sec -= min * 60
    # min -= deg * 60
    # return "#{deg}°#{min}′#{sec}″#{val < 0 ? dir2 : dir1}"
  end

  def map_control_init(gmap, marker, args, type='ct')
    name = args[:marker_name] || 'mo_marker'
    gmap.overlay_global_init(marker, name + '_' + type)
    gmap.event_init(marker, 'dragend', "function(latlng) {
      dragEndLatLng(latlng, '#{type}')
    }")
  end

  def map_box_control_init(gmap, set, args)
    for point, type in [
      [set.north_west, 'nw'],
      [set.north_east, 'ne'],
      [set.south_west, 'sw'],
      [set.south_east, 'se'],
    ]
      marker = GM::GMarker.new(point, :draggable => true)
      map_control_init(gmap, marker, args, type)
    end
  end

  # Center on a given location? (This is never used: -JPH 20120510)
  # if respond_to?(:start_lat) && respond_to?(:start_long)
  #   gmap.center_zoom_init( [start_lat, start_long], GM::Constants::GM_ZOOM )
  #   gmap.overlay_init(
  #     GM::GMarker.new( [start_lat, start_long],
  #       :icon => icon_start,
  #       :title => name + " start",
  #       :info_window => "start"
  #   ))
  # end

  # Started playing with icons and the following got something to show up,
  # but I decide not to pursue it further right now.
  # gmap.icon_global_init(
  #   GM::GIcon.new(
  #     :image => "/images/blue-dot.png",
  #     :icon_size => GM::GSize.new( 24,38 ),
  #     :icon_anchor => GM::GPoint.new(12,38),
  #     :info_window_anchor => GM::GPoint.new(9,2)
  #   ), "blue_dot")
  # blue_dot = GM::Variable.new("blue_dot")
end

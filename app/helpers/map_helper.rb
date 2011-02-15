# encoding: utf-8
#
#  = Google Maps Helpers
#
#  XXX
#
#  *NOTE*: These are all included in ApplicationHelper.
#
#  == Methods
#
#  make_map::       Create a map of the given Locations.
#  finish_map::     Render the header needed for the given map.
#  map_loc::        Add a dot to the map.
#
#  == Usage
#
#    <%
#      # Create the map first.
#      gmap = make_map(@locations)
#      # (tweak gmap here)
#      # map_loc(gmap, location)
#      # etc.
#   
#      # Install some necessary header fields.
#      add_header(GMap.header)
#      add_header(finish_map(gmap))
#    %>
#   
#    ...
#   
#    <%=
#      # Place this object where you want the map to appear.
#      gmap.div(:width => 400, :height => 400)
#    %>
#
##############################################################################

module ApplicationHelper::Map

  def overlay_init(map, marker, name)
    map.overlay_global_init(marker, 'mo_marker_' + name)
    map.event_init(marker, 'dragend', "function(latlng) {dragEndLatLng(latlng, '#{name}')}")
  end
  
  # Draw a single Location on the given GMap.
  def map_loc(map, loc, query_params={}, marker_name = nil, box_name = nil)
    link = link_to(loc.display_name.t, :controller => :location,
                   :action => :show_location, :id => loc.id,
                   :params => query_params)
    marker = GMarker.new(
      loc.center(),
      :title => loc.display_name,
      :draggable => (marker_name != nil))
    if marker_name
      overlay_init(map, marker, 'ct')
      overlay_init(map, GMarker.new(loc.north_west, :draggable => true), 'nw')
      overlay_init(map, GMarker.new(loc.north_east, :draggable => true), 'ne')
      overlay_init(map, GMarker.new(loc.south_east, :draggable => true), 'se')
      overlay_init(map, GMarker.new(loc.south_west, :draggable => true), 'sw')
    else
      table = make_table([
        ['', h(loc.north), ''],
        [h(loc.west), '', h(loc.east)],
        ['', h(loc.south), '']
      ])
      info = '<span class="gmap">' + link + table + '</span>'
      marker.info_window = info
      map.overlay_init(marker)
    end
    west_east = (loc.east + loc.west)/2
    west_east = west_east + 180 if (loc.west > loc.east)
    box = GPolyline.new([
        [loc.north, loc.west],
        [loc.north, west_east],
        [loc.north, loc.east],
        [loc.south, loc.east],
        [loc.south, west_east],
        [loc.south, loc.west],
        [loc.north, loc.west],
      ], "#00ff88", 3, 1.0)
    if box_name
      map.overlay_global_init(box, box_name)
    else
      map.overlay_init(box)
    end
  end

  # Create a map of a given Array of Location's.  It creates the map, centers
  # and zooms it, then draws all the locations on it.  Returns a GMap instance.
  def make_map(locs, query_params={})
    gmap = GMap.new("map_div")
    gmap.control_init(:large_map => true, :map_type => true)

    # Center on a given location?
    if respond_to?(:start_lat) && respond_to?(:start_long)
      map.center_zoom_init( [start_lat, start_long], Constants::GM_ZOOM )
      map.overlay_init(
        GMarker.new( [start_lat, start_long],
          :icon => icon_start,
          :title => name + " start",
          :info_window => "start"
      ))
    end

    # Center based on the points we're drawing on it.
    gmap.center_zoom_on_points_init(
      *(locs.map(&:south_west) + locs.map(&:north_east))
    )

    # Started playing with icons and the following got something to show up, but I decide
    # not to pursue it further right now.
    # gmap.icon_global_init(
    #   GIcon.new(
    #     :image => "/images/blue-dot.png",
    #     :icon_size => GSize.new( 24,38 ),
    #     :icon_anchor => GPoint.new(12,38),
    #     :info_window_anchor => GPoint.new(9,2)
    #   ), "blue_dot")
    # blue_dot = Variable.new("blue_dot")

    # Map locations.
    for l in locs
      # map_loc(gmap, l, query_params, blue_dot)
      map_loc(gmap, l, query_params)
    end
    
    gmap
  end

  # Create a map of a single Location.  It creates the map, centers
  # and zooms it, then draws the locations on it.  The Marker for the
  # location is named 'mo_center_marker' and the surrounding rectangle is named
  # 'mo_box'.  Returns a GMap instance.
  def make_editable_map(loc, query_params={})
    gmap = GMap.new("map_div")
    gmap.control_init(:large_map => true, :map_type => true)

    # Center on a given location?
    if respond_to?(:start_lat) && respond_to?(:start_long)
      map.center_zoom_init( [start_lat, start_long], Constants::GM_ZOOM )
      map.overlay_init(
        GMarker.new( [start_lat, start_long],
          :icon => icon_start,
          :title => name + " start",
          :info_window => "start"
      ))
    end
    gmap.center_zoom_on_points_init(loc.north_west, loc.center, loc.south_east)
    map_loc(gmap, loc, query_params, "mo_center_marker", "mo_box")
    gmap.event_init(gmap, 'click', 'function(overlay, latlng) {
      clickLatLng(latlng);
    }')
    gmap.event_init(gmap, 'dblclick', 'function(overlay, latlng) {
      dblClickLatLng(latlng);
    }')
    gmap
  end

  # Render the given GMap.
  def finish_map(map)
    javascript_tag(map.to_html(:no_script_tag => 1))
  end
end

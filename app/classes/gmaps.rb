# frozen_string_literal: true

#  = Google Maps interface
#
#  GM::GMap::      Represents a "google.maps.Map" object.
#  GM::Marker::    Represents a "google.maps.Marker" object, i.e., a balloon-pin
#  GM::Polyline::  Represents a "google.maps.Polyline" object, e.g., a rectangle
#
#  == Typical Usage
#
#  This is meant to be a drop-in replacement for the old out-dated ym4r_gm
#  plug-in. This version uses google maps api version 3, instead of version 2,
#  which has been officially discontinued by google.  However, note that it
#  only replicates that functionality which we were actually using at the time
#  of the replacement (November 2013).
#
#    <%
#      # Create and initialize map.
#      gmap = GM::GMap.new("map_div")
#      gmap.control_init(:large_map => true, :map_type => true)
#      gmap.center_zoom_on_points_init(*lat_longs)
#      gmap.event_init(gmap, 'click', 'function(obj, lat_long) { ... }')
#
#      # Create and attach a marker pin.
#      marker = GM::GMarker.new([lat, long], :title => "roll-over text")
#      marker.info_window = "html mark-up"
#      gmap.overlay_global_init(marker, "marker_id")
#      gmap.event_init(marker, 'dragend', "function(lat_long) { ... }')
#
#      # Overlay a polygon.
#      line = GM::GPolyline.new(points, "#rrggbb", width, opacity)
#      gmap.overlay_init(line)
#    %>
#
#    <head>
#      <%= GM::GMap.header(:host => MO.domain) %>
#      <%= javascript_tag(gmap.to_html) %>
#    </head>
#    <body>
#      <%= gmap.div(:width => 800, :height => 600) %>
#    </body>
#
module GM
  GMAPS_API_URL = "https://maps.googleapis.com/maps/api/js"
  GMAPS_CONFIG_FILE = "config/gmaps_api_key.yml"
  GMAPS_API_KEYS = YAML.load_file(::Rails.root.to_s + "/" + GMAPS_CONFIG_FILE)

  # represent a GoogleMaps map object
  class GMap
    # Escape carrier returns, single and double quotes for JavaScript segments.
    # Lifted from ActionView::Helpers::JavascriptHelper (2.1.1) -JPH
    def self.escape_javascript(javascript)
      (javascript || "").gsub('\\', '\0\0').gsub("</", '<\/').
        gsub(/\r\n|\n|\r/, "\\n").gsub(/["']/) { |m| "\\#{m}" }
    end

    def self.header(args)
      url = GMAPS_API_URL
      key = GMAPS_API_KEYS[::Rails.env][args[:host]]
      "<script type='text/javascript' src='#{url}?key=#{key}&sensor=false'>"\
      "</script>
      <script type='text/javascript'>
        var G = google.maps;
        // in case jQuery is not loaded for this page
        function E(id) {
          return document.getElementById(id);
        }
        // handy to reduce space required for long lists of latilongs
        function L(lat, long) {
          return new G.LatLng(lat, long);
        }
        // callback to close currently opened info window
        var current_info_window = null;
        var has_info_window_closer = {};
        function close_current_info_window() {
          if (current_info_window) {
            current_info_window.close();
            current_info_window = null;
          }
        }
        // handy to create fully-functional marker pin with popup info-window
        function P(map, lat, long, draggable, title, popup_content) {
          var marker;
          var info_window;
          var args = {
            map:      map,
            position: L(lat, long)
          };
          if (title != 0)     args['title'] = title;
          if (draggable != 0) args['draggable'] = true;
          marker = new G.Marker(args);
          if (popup_content != 0) {
            info_window = new G.InfoWindow({content: popup_content});
            G.event.addListener(marker, 'click', function() {
              info_window.open(map, marker);
              current_info_window = info_window;
            });
            if (!has_info_window_closer[map]++)
              G.event.addListener(map, 'click', close_current_info_window);
          }
          return marker;
        }
      </script>".html_safe
    end

    attr_accessor :name       # name of map div & global variable for Map object
    attr_accessor :lat        # center & zoom \
    attr_accessor :long       #                |  option one for positioning map
    attr_accessor :zoom       #               /
    attr_accessor :north      # bounds \
    attr_accessor :south      #         \  option two for positioning map
    attr_accessor :east       #         /
    attr_accessor :west       #        /
    attr_accessor :large      # is this a "large" map? (versus "small")
    attr_accessor :events     # array of [overlay_obj, event_type, javascript]
    attr_accessor :overlays   # array of markers and polylines to overlay on map

    def initialize(name)
      self.name     = name
      self.lat      = nil
      self.long     = nil
      self.zoom     = nil
      self.north    = nil
      self.south    = nil
      self.east     = nil
      self.west     = nil
      self.large    = true
      self.events   = []
      self.overlays = []
    end

    alias var name

    def center_zoom_init(center, zoom)
      self.lat  = center[0]
      self.long = center[1]
      self.zoom = zoom
    end

    def center_zoom_on_points_init(*points)
      north = south = nil
      east1 = west1 = nil  # E and W edges assuming not straddling date line
      east2 = west2 = nil  # E and West edges assuming DOES straddle date line
      for lat, long in points
        north = lat  if north.nil? || lat > north
        south = lat  if south.nil? || lat < south
        east1 = long if east1.nil? || long > east1
        west1 = long if west1.nil? || long < west1
        long += 360 if long.negative?
        east2 = long if east2.nil? || long > east2
        west2 = long if west2.nil? || long < west2
      end
      self.north = north
      self.south = south
      if east1 - west1 < east2 - west2
        self.east = east1
        self.west = west1
      else
        self.east = east2
        self.west = west2
      end
    end

    def control_init(args)
      self.large = !!args[:large_map]
    end

    def overlay_init(obj)
      overlays << obj
    end

    def overlay_global_init(obj, var)
      obj.var = var
      overlays << obj
    end

    def event_init(obj, event, code)
      events << [obj, event, code]
    end

    def div(args)
      width = height = nil
      args.each do |key, val|
        if key == :width
          width = val
        elsif key == :height
          height = val
        else
          raise "Unexpected option \"#{key}\" for GMap#div."
        end
      end
      height = height.to_s + "px" if height.is_a?(Integer)
      width = width.to_s + "px" if width.is_a?(Integer)
      "<div id='#{name}' style='width:#{width};height:#{height}'></div>"
    end

    def to_html(_args)
      "#{global_declarations_code}\n" \
      "G.event.addDomListener(window, 'load', function() {\n" \
        "var M = #{name} = new G.Map(E('#{name}'), "\
        "{ #{map_options_code.join(", ")} });\n" \
        "#{center_map_code}\n" \
        "#{overlays_code}\n" \
        "#{events_code}\n" \
      "});"
    end

    def global_declarations_code
      result = + "var #{name};" # create mutable string
      overlays.each { |obj| result += "\nvar #{obj.var};" if obj.var }
      result
    end

    def map_options_code
      [
        "mapTypeControl:#{large ? "true" : "false"}",
        "mapTypeId:G.MapTypeId.#{large ? "TERRAIN" : "ROADMAP"}"
      ]
    end

    def center_map_code
      if zoom
        "M.setCenter(L(#{lat}, #{long}));\n" \
        "M.setZoom(#{zoom});"
      else
        "M.fitBounds(new G.LatLngBounds( L(#{south},#{west}), "\
        "L(#{north},#{east}) ));"
      end
    end

    def overlays_code
      result = + "" # create mutable string
      overlays.each { |obj| result += obj.create_and_initialize_code + ";\n" }
      result.sub!(/\n\Z/, "")
      result
    end

    def events_code
      result = + "" # create mutable string
      events.each do |obj, event, code|
        result += "G.event.addListener(#{obj.var}, '#{event}', #{code});\n"
      end
      result.sub!(/\n\Z/, "")
      result
    end
  end

  # represent a GoogleMaps marker object, e.g., a balloon-pin
  class GMarker
    attr_accessor :var          # name of global variable to assign it to if any
    attr_accessor :lat          # latitude
    attr_accessor :long         # longitude
    attr_accessor :title        # roll-over text
    attr_accessor :draggable    # is this draggable?
    # content of "info window" to pop up if user clicks on marker
    attr_accessor :info_window

    def initialize(lat_long, opts)
      self.var         = nil
      self.lat         = lat_long[0]
      self.long        = lat_long[1]
      self.title       = nil
      self.draggable   = false
      self.info_window = nil
      opts.each_key do |key|
        if key == :draggable
          self.draggable = !!opts[key]
        elsif key == :title
          self.title = opts[key].to_s
        else
          raise "Unexpected option \"#{key}\" for GMarker."
        end
      end
    end

    def create_and_initialize_code
      assign = var ? "#{var}=" : ""
      args = [
        "M", lat, long,
        (draggable ? "1" : "0"),
        (title ? "'#{GMap.escape_javascript(title)}'" : "0"),
        (info_window ? "'#{GMap.escape_javascript(info_window)}'" : "0")
      ]
      "#{assign}P(#{args.join(",")})"
    end
  end

  # represent a GoogleMaps Polyline object, e.g., a rectangle
  class GPolyline
    attr_accessor :var      # name of global variable to assign it to if any
    attr_accessor :points   # array of [lat, long]
    attr_accessor :color    # css-format color string
    attr_accessor :weight   # width of line in pixels
    attr_accessor :opacity  # from 0.0 to 1.0

    def initialize(points, color, weight, opacity)
      self.var     = nil
      self.points  = points
      self.color   = color
      self.weight  = weight
      self.opacity = opacity
    end

    def create_and_initialize_code
      assign = var ? "#{var}=" : ""
      opts   = [
        "map:M",
        "path:[#{points.map { |y, x| "L(#{y},#{x})" }.join(",")}]",
        "strokeColor:'#{GMap.escape_javascript(color)}'",
        "strokeOpacity:#{opacity}",
        "strokeWeight:#{weight}"
      ]
      "#{assign}new G.Polyline({#{opts.join(",")}})"
    end
  end
end

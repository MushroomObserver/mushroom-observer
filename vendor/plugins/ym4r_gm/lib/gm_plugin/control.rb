module Ym4r
  module GmPlugin
    #Small map control. Report to the Google Maps API documentation for details.
    class GSmallMapControl
      include MappingObject
      def create
        "new GSmallMapControl()"
      end
    end
    #Large Map control. Report to the Google Maps API documentation for details.
    class GLargeMapControl
      include MappingObject
      def create
        "new GLargeMapControl()"
      end
    end
    #Small Zoom control. Report to the Google Maps API documentation for details.
    class GSmallZoomControl
      include MappingObject
      def create
        "new GSmallZoomControl()"
      end
    end
    #Scale control. Report to the Google Maps API documentation for details.
    class GScaleControl
      include MappingObject
      def create
        "new GScaleControl()"
      end
    end
    #Map type control. Report to the Google Maps API documentation for details.
    class GMapTypeControl
      include MappingObject
      def create
        "new GMapTypeControl()"
      end
    end
    #Overview map control. Report to the Google Maps API documentation for details.
    class GOverviewMapControl
      include MappingObject
      def create
        "new GOverviewMapControl()"
      end
    end

    #An object representing a position of a control.
    #The first argument of the constructor is one of the following : :top_right, :top_left, :bottom_right, :bottom_left.
    class GControlPosition < Struct.new(:anchor,:offset)
      include MappingObject
      def create
        js_anchor = if anchor == :top_right
                      "G_ANCHOR_TOP_RIGHT"
                    elsif anchor == :top_left
                      "G_ANCHOR_TOP_LEFT"
                    elsif anchor == :bottom_right
                      "G_ANCHOR_BOTTOM_RIGHT"
                    else
                      "G_ANCHOR_BOTTOM_LEFT"
                    end
        "new GControlPosition(#{js_anchor},#{offset})"
      end
    end
  end
end

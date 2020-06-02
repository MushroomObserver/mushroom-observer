# frozen_string_literal: true

require "net/http"
require "rexml/document"

#  = Geocoder Class
#
#  Wraps a call to the Google Geocoding webservice
#
class Geocoder < BlankSlate
  attr_reader :north
  attr_reader :south
  attr_reader :east
  attr_reader :west
  attr_reader :valid

  GMAPS_CONFIG_FILE = "config/gmaps_api_key.yml"
  GMAPS_API_KEYS = YAML.load_file(::Rails.root.to_s + "/" + GMAPS_CONFIG_FILE)

  def initialize(place_name)
    @place_name = place_name
    @valid = false
    set_extents(nil, nil, nil, nil)
    return unless place_name

    rectangle_from_content(content_from_place_name(place_name))
  end

  def rectangle_from_content(content)
    xml = REXML::Document.new(content)
    xml.elements.each("GeocodeResponse/result/geometry") do |geom|
      set_bounds(geom)
    end
  end

  def set_bounds(geom)
    set_rect_elements(geom)
    set_loc_elements(geom)
  end

  def set_rect_elements(geom)
    return unless (rect = bounds_or_viewport(geom))

    sw = rect.elements["southwest"]
    ne = rect.elements["northeast"]
    set_extents(ne.elements["lat"].text,
                sw.elements["lat"].text,
                ne.elements["lng"].text,
                sw.elements["lng"].text)
    @valid = true
  end

  def bounds_or_viewport(geom)
    geom.elements["bounds"] || geom.elements["viewport"]
  end

  def set_loc_elements(geom)
    return unless (loc = geom.elements["location"])

    lat = loc.elements["lat"].text
    lng = loc.elements["lng"].text
    set_extents(lat, lat, lng, lng)
    @valid = true
  end

  def set_extents(north, south, east, west)
    @north = north
    @south = south
    @east = east
    @west = west
  end

  def ajax_response
    [north, south, east, west].join("\n") + "\n"
  end

  def request_url(place_name)
    str = u(place_name.gsub("Co.", "County"))
    key = gmaps_key
    "/maps/api/geocode/xml?address=#{str}&key=#{key}&sensor=false"
  end

  def gmaps_key
    GMAPS_API_KEYS[::Rails.env][MO.domain]
  end

  def content_from_place_name(place_name)
    if Rails.env.test?
      content = test_place_name(place_name)
    else
      content = nil
      uri = URI("https://maps.google.com")
      Net::HTTP.start(uri.host, uri.port, use_ssl: true) do |http|
        response = http.get(request_url(place_name))
        content = response.body
      end
    end
    content
  end

  def test_place_name(place_name)
    if (loc = TEST_EXPECTED_LOCATIONS[place_name])
      test_success(loc)
    else
      TEST_FAILURE
    end
  end

  unless defined? TEST_EXPECTED_LOCATIONS
    TEST_EXPECTED_LOCATIONS = {
      "North Falmouth, Massachusetts, USA" => {
        south: 41.6169329,
        west: -70.6603389,
        north: 41.6592100,
        east: -70.6022670
      },
      "North bound Rest Area, State Highway 33, between Pomeroy and Athens, "\
      "Ohio, USA" => {
        north: 39.3043,
        west: -82.1067,
        east: -82.002,
        south: 39.0299
      },
      "Pasadena, California, USA" => {
        north: 34.251905,
        west: -118.198139,
        east: -118.065479,
        south: 34.1192
      }
    }.freeze
  end

  unless defined? TEST_FAILURE
    TEST_FAILURE = '<?xml version="1.0" encoding="UTF-8"?>
    <GeocodeResponse>
     <status>ZERO_RESULTS</status>
    </GeocodeResponse>'
  end

  def test_success(loc)
    "<?xml version=\"1.0\" encoding=\"UTF-8\"?>
      <GeocodeResponse>
       <result>
        <geometry>
         <bounds>
          <southwest>
           <lat>#{loc[:south]}</lat>
           <lng>#{loc[:west]}</lng>
          </southwest>
          <northeast>
           <lat>#{loc[:north]}</lat>
           <lng>#{loc[:east]}</lng>
          </northeast>
         </bounds>
        </geometry>
       </result>
      </GeocodeResponse>"
  end
end

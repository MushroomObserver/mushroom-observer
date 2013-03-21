# encoding: utf-8
#
#  = Geocoder Class
#
#  Wraps a call to the Google Geocoding webservice
#
################################################################################

require 'net/http'
require 'rexml/document'

class Geocoder < BlankSlate

  attr_reader :north
  attr_reader :south
  attr_reader :east
  attr_reader :west
  attr_reader :valid
  attr_reader :ajax_response
  
  def initialize(place_name)
    @valid = false
    calc_response(nil, nil, nil, nil)
    if place_name
      set_rectangle_from_content(content_from_place_name(place_name))
    end
  end
  
  def set_rectangle_from_content(content)
    xml = REXML::Document.new(content)
    xml.elements.each('GeocodeResponse/result/geometry') do |geom|
      rect = geom.elements['bounds'] || geom.elements['viewport']
      if rect
        sw = rect.elements['southwest']
        ne = rect.elements['northeast']
        calc_response(ne.elements['lat'].text, sw.elements['lat'].text, ne.elements['lng'].text, sw.elements['lng'].text)
        @valid = true
      else
        loc = geom.elements['location']
        if loc
          lat = loc.elements['lat'].text
          lng = loc.elements['lng'].text
          calc_response(lat, lat, lng, lng)
          @valid = true
        end
      end
    end
  end
  
  def calc_response(north, south, east, west)
    @north = north
    @south = south
    @east = east
    @west = west
    @ajax_response = [north, south, east, west].join("\n") + "\n"
  end
  
  def content_from_place_name(place_name)
    if RAILS_ENV != 'production'
      content = test_place_name(place_name)
    else
      content = nil
      url = "/maps/api/geocode/xml?address=#{u(place_name.gsub('Co.', 'County'))}&sensor=false"
      Net::HTTP.start('maps.google.com') do |http|
        response = http.get(url)
        content = response.body
      end
    end
    content
  end
  
  def test_place_name(place_name)
    loc = TEST_EXPECTED_LOCATIONS[place_name]
    if loc
      content = test_success(loc)
    else
      content = TEST_FAILURE
    end
  end

  TEST_EXPECTED_LOCATIONS = {
    'North Falmouth, Massachusetts, USA' => {
      :south => 41.6169329,
      :west => -70.6603389,
      :north => 41.6592100,
      :east => -70.6022670
    },
    'North bound Rest Area, State Highway 33, between Pomeroy and Athens, Ohio, USA' => {
      :north => 39.3043,
      :west => -82.1067,
      :east => -82.002,
      :south => 39.0299
    },
    'Pasadena, California, USA' => {
      :north => 34.251905,
      :west => -118.198139,
      :east => -118.065479,
      :south => 34.1192
    }
  }

  TEST_FAILURE = '<?xml version="1.0" encoding="UTF-8"?>
  <GeocodeResponse>
   <status>ZERO_RESULTS</status>
  </GeocodeResponse>'
  
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

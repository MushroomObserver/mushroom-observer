#
#  = Geocoder Class
#
#  Wraps a call to the Google Geocoding webservice
#
################################################################################

require 'net/http'
require 'rexml/document'

def geocode_address(address)
end

class Geocoder < BlankSlate

  attr_reader   :north
  attr_reader   :south
  attr_reader   :east
  attr_reader   :west
  attr_reader   :valid
  
  # Contructor takes a Hash of attributes you want the object to have.
  def initialize(address)
    @north	= @south	= @west = @east = nil
    @valid = false
    if address
      content = nil
      url = "/maps/api/geocode/xml?address=#{u(address.gsub('Co.', 'County'))}&sensor=false"
      Net::HTTP.start('maps.google.com') do |http|
        response = http.get(url)
        content = response.body
      end
      xml = REXML::Document.new(content)
      xml.elements.each('GeocodeResponse/result/geometry') do |geom|
        rect = geom.elements['bounds'] || geom.elements['viewport']
        if rect
          sw = rect.elements['southwest']
          @south = sw.elements['lat'].text
          @west = sw.elements['lng'].text
          ne = rect.elements['northeast']
          @north = ne.elements['lat'].text
          @east = ne.elements['lng'].text
          @valid = true
        else
          loc = geom.elements['location']
          if loc
            @north = @south = loc.elements['lat'].text
            @east = @west = loc.elements['lng'].text
            @valid = true
          end
        end
      end
    end
  end
  
  def ajax_response()
    [@north, @south, @east, @west].join("\n") + "\n"
  end
end

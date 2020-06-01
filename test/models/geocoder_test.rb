# frozen_string_literal: true

require "test_helper"

class GeocoderTest < UnitTestCase
  def test_unknown_place_name
    obj = Geocoder.new("Somewhere Out There")
    assert_not(obj.valid)
    assert_nil(obj.north)
  end

  def test_falmouth
    obj = Geocoder.new("North Falmouth, Massachusetts, USA")
    assert(obj.valid)
    assert(obj.north)
    assert(obj.south)
    assert(obj.east)
    assert(obj.west)
    assert_equal("#{obj.north}\n#{obj.south}\n#{obj.east}\n#{obj.west}\n",
                 obj.ajax_response)
  end
end

require File.dirname(__FILE__) + '/../boot'

class GeocoderTest < UnitTestCase

  def test_create
    obj = Geocoder.new('North Falmouth, Massachusetts, USA')
    assert(obj.valid)
    assert(obj.north)
    assert(obj.south)
    assert(obj.east)
    assert(obj.west)
    assert_equal("#{obj.north}\n#{obj.south}\n#{obj.east}\n#{obj.west}\n", obj.ajax_response)
    obj = Geocoder.new('Turkey Point, Ontario, Canada')
    assert(obj.valid)
    obj = Geocoder.new('Somewhere Out There')
    assert(!obj.valid)
    assert_nil(obj.north)
  end
end

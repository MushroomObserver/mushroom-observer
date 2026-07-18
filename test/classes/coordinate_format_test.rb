# frozen_string_literal: true

require("test_helper")

class CoordinateFormatTest < UnitTestCase
  class Stub
    include CoordinateFormat
  end

  def test_display_lat_lng_north_west
    stub = Stub.new
    assert_equal("34.1622°N 118.3521°W",
                 stub.display_lat_lng(34.1622, -118.3521))
  end

  def test_display_lat_lng_south_east
    stub = Stub.new
    assert_equal("34.1622°S 118.3521°E",
                 stub.display_lat_lng(-34.1622, 118.3521))
  end

  def test_display_lat_lng_no_lat
    stub = Stub.new
    assert_equal("", stub.display_lat_lng(nil, nil))
  end

  def test_display_alt
    stub = Stub.new
    assert_equal("", stub.display_alt(nil))
    assert_equal("1234m", stub.display_alt(1234))
  end

  def test_place_name_and_coordinates_with_values
    stub = Stub.new
    assert_equal(
      "Pasadena, California, USA (34.1622°N 118.3521°W)",
      stub.place_name_and_coordinates(
        "Pasadena, California, USA", 34.1622, -118.3521
      )
    )
  end

  def test_place_name_and_coordinates_no_coordinates
    stub = Stub.new
    assert_equal(
      "Who knows where",
      stub.place_name_and_coordinates("Who knows where", nil, nil)
    )
  end

  def test_format_latitude
    stub = Stub.new
    assert_equal("34.1622°N", stub.format_latitude(34.1622))
    assert_equal("34.1622°S", stub.format_latitude(-34.1622))
  end

  def test_format_longitude
    stub = Stub.new
    assert_equal("118.3521°E", stub.format_longitude(118.3521))
    assert_equal("118.3521°W", stub.format_longitude(-118.3521))
  end
end

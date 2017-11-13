# API
class API
  def parse_location(key, args = {})
    declare_parameter(key, :location, args)
    str = get_param(key)
    return args[:default] unless str
    raise BadParameterValue.new(str, :location) if str.blank?
    val = try_parsing_id(str, Location) ||
          Location.find_by_name_or_reverse_name(str)
    return val if val
    raise ObjectNotFoundByString.new(get_param(key), Location)
  end

  def parse_place_name(key, args = {})
    val = parse_location(key, args)
    val.is_a?(Location) ? val.display_name : val
  rescue ObjectNotFoundByString
    get_param(key)
  end

  def parse_altitude(key, args = {})
    parse_location_component(key, :altitude, args)
  end

  def parse_latitude(key, args = {})
    parse_location_component(key, :latitude, args)
  end

  def parse_longitude(key, args = {})
    parse_location_component(key, :longitude, args)
  end

  def parse_location_component(key, type, args)
    declare_parameter(key, type, args)
    str = get_param(key)
    return args[:default] unless str
    val = Location.send("parse_#{type}", str)
    raise BadParameterValue.new(str, type) unless val
    val
  end

  def parse_altitude_compact_range?; end

  def parse_latitude_compact_range?; end

  def parse_longitude_compact_range?; end
end

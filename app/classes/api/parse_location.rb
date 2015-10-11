# encoding: utf-8

# Manages the Mushroom Observer Application Programming Interface
class API
  def parse_latitude(key, args = {})
    declare_parameter(key, :latitude, args)
    str = get_param(key)
    return args[:default] unless str
    val = Location.parse_latitude(str)
    fail BadParameterValue.new(str, :latitude) unless val
    val
  end

  def parse_longitude_range(key, args = {})
    do_parse_range(:parse_longitude, key, args.merge(leave_order: true))
  end

  def parse_longitude(key, args = {})
    declare_parameter(key, :longitude, args)
    str = get_param(key)
    return args[:default] unless str
    val = Location.parse_longitude(str)
    fail BadParameterValue.new(str, :longitude) unless val
    val
  end

  def parse_altitude(key, args = {})
    declare_parameter(key, :altitude, args)
    str = get_param(key)
    return args[:default] unless str
    val = Location.parse_altitude(str)
    fail BadParameterValue.new(str, :altitude) unless val
    val
  end

  def parse_location(key, args = {})
    declare_parameter(key, :location, args)
    str = get_param(key)
    return args[:default] unless str
    fail BadParameterValue.new(str, :location) if str.blank?
    val = try_parsing_id(str, Location)
    val ||= Location.find_by_name_or_reverse_name(str)
    fail ObjectNotFoundByString.new(str, Location) unless val
    val
  end

  def parse_place_name(key, args = {})
    declare_parameter(key, :place_name, args)
    str = get_param(key)
    return args[:default] unless str
    fail BadParameterValue.new(str, :location) if str.blank?
    val = try_parsing_id(str, Location)
    val ||= Location.find_by_name_or_reverse_name(str)
    val ? val.display_name : str
  end
end

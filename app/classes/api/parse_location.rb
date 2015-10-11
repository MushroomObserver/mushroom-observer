# encoding: utf-8

# Manages the Mushroom Observer Application Programming Interface
class API
  def location_component(key, what, args)
    declare_parameter(key, what, args)
    str = get_param(key)
    return args[:default] unless str
    case what
    when :altitude then val = Location.parse_altitude(str)
    when :latitude then val = Location.parse_latitude(str)
    when :longitude then val = Location.parse_longitude(str)
    end
    fail BadParameterValue.new(str, what) unless val
    val
  end

  def parse_altitude(key, args = {})
    location_component(key, :altitude, args)
  end

  def parse_latitude(key, args = {})
    location_component(key, :latitude, args)
  end

  def parse_longitude(key, args = {})
    location_component(key, :longitude, args)
  end

  def parse_longitude_range(key, args = {})
    do_parse_range(:parse_longitude, key, args.merge(leave_order: true))
  end

  def location_val(key, what, args)
    declare_parameter(key, what, args)
    str = get_param(key)
    return args[:default] unless str
    fail BadParameterValue.new(str, what) if str.blank?
    val = try_parsing_id(str, Location)
    val ||= Location.find_by_name_or_reverse_name(str)
    return val if val
    fail ObjectNotFoundByString.new(get_param(key), Location)
  end

  def parse_location(key, args = {})
    location_val(key, :location, args)
  end

  def parse_place_name(key, args = {})
    val = location_val(key, :place_name, args)
    val.is_a?(Location) ? val.display_name : val
  rescue ObjectNotFoundByString
    get_param(key)
  end
end

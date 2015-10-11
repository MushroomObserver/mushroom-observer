# encoding: utf-8

# Manages the Mushroom Observer Application Programming Interface
class API
  def parse_license(key, args = {})
    declare_parameter(key, :license, args)
    str = get_param(key)
    return args[:default] unless str
    val = try_parsing_id(str, License)
    fail BadParameterValue.new(str, :license) unless val
    val
  end
end

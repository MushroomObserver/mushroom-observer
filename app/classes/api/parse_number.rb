# encoding: utf-8

# Manages the Mushroom Observer Application Programming Interface
class API
  def parse_integer(key, args = {})
    declare_parameter(key, :integer, args)
    str = get_param(key)
    return args[:default] unless str
    fail BadParameterValue.new(str, :integer) unless str.match(/^-?\d+$/)
    val = str.to_i
    limit = args[:limit]
    return val unless limit
    fail BadLimitedParameterValue.new(str, limit) unless limit.include?(val)
    val
  end

  def parse_float(key, args = {})
    declare_parameter(key, :float, args)
    str = get_param(key)
    return args[:default] unless str
    float_pattern = /^(-?\d+(\.\d+)?|-?\.\d+)$/
    fail BadParameterValue.new(str, :float) unless str.match(float_pattern)
    val = str.to_f
    limit = args[:limit]
    return val unless limit
    fail BadLimitedParameterValue.new(str, limit) unless limit.include?(val)
    val
  end
end

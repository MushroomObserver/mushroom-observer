# API
class API
  def parse_integer(key, args = {})
    declare_parameter(key, :integer, args)
    str = get_param(key)
    return args[:default] unless str
    raise BadParameterValue.new(str, :integer) if str !~ /^-?\d+$/
    val = str.to_i
    limit = args[:limit]
    return val unless limit
    raise BadLimitedParameterValue.new(str, limit) unless limit.include?(val)
    val
  end

  def parse_float(key, args = {})
    declare_parameter(key, :float, args)
    str = get_param(key)
    return args[:default] unless str
    float_pattern = /^(-?\d+(\.\d+)?|-?\.\d+)$/
    raise BadParameterValue.new(str, :float) unless str.match(float_pattern)
    val = str.to_f
    limit = args[:limit]
    return val unless limit
    raise BadLimitedParameterValue.new(str, limit) unless limit.include?(val)
    val
  end
end

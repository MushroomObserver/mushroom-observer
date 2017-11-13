# API
class API
  def parse_enum(key, args = {})
    declare_parameter(key, :enum, args)
    str = get_param(key)
    return args[:default] unless str
    limit = args[:limit]
    raise("missing limit!") unless limit
    limit.each do |val|
      return val if str.casecmp(val.to_s).zero?
    end
    raise BadLimitedParameterValue.new(str, limit)
  end

  def parse_enum_swap_order?(from, to, args)
    limit = args[:limit]
    limit.index(from) > limit.index(to)
  end

  def parse_enum_compact_range?; end
end

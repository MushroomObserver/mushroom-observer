# encoding: utf-8

# Manages the Mushroom Observer Application Programming Interface
class API
  def parse_enum_range(key, args = {})
    val = do_parse_range(:parse_enum, key, args)
    if val.is_a?(OrderedRange)
      limit = args[:limit]
      if limit.index(val.begin) > limit.index(val.end)
        val = OrderedRange.new(val.end, val.begin)
      end
    end
    val
  end

  def parse_enum(key, args = {})
    declare_parameter(key, :enum, args)
    str = get_param(key)
    return args[:default] unless str
    limit = args[:limit]
    fail "missing limit!" unless limit
    limit.each do |val|
      return val if str.downcase == val.to_s.downcase
    end
    fail BadLimitedParameterValue.new(str, limit)
  end
end

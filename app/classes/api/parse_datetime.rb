# encoding: utf-8

# Manages the Mushroom Observer Application Programming Interface
class API
  def parse_date(key, args = {})
    declare_parameter(key, :date, args)
    str = get_param(key)
    return args[:default] unless str
    if Patterns.date(str)
      return Date.parse(str)
    else
      fail BadParameterValue.new(str, :date)
    end
  rescue ArgumentError
    raise BadParameterValue.new(str, :date)
  end

  def parse_time(key, args = {})
    declare_parameter(key, :time, args)
    str = get_param(key)
    return args[:default] unless str
    if Patterns.seconds(str)
      return DateTime.parse(str)
    else
      fail BadParameterValue.new(str, :time)
    end
  rescue ArgumentError
    raise BadParameterValue.new(str, :time)
  end

  def parse_date_range(key, args = {})
    declare_parameter(key, :date_range, args)
    str = get_param(key)
    return args[:default] unless str
    DateRange.parse(str)
  end

  def parse_time_range(key, args = {})
    declare_parameter(key, :time_range, args)
    str = get_param(key)
    return args[:default] unless str
    TimeRange.parse(str) || date_parse_for_time(str, args)
  end

  def date_parse_for_time(str, args)
    val = parse_date_range(str, args)
    begin_time = val.is_a?(OrderedRange) ? val.begin : val
    end_time = val.is_a?(OrderedRange) ? val.end : val
    OrderedRange.new(DateTime.parse(begin_time.to_s + " 01:01:01"),
                     DateTime.parse(end_time.to_s + " 23:59:59"))
  end
end

# API
class API
  def class_parse(key, method, cls, patterns, args)
    declare_parameter(key, method, args)
    str = get_param(key)
    return args[:default] unless str
    return cls.parse(str) if Patterns.list_matcher(str, patterns)
    raise BadParameterValue.new(str, method)
  rescue ArgumentError
    raise BadParameterValue.new(str, method)
  end

  def parse_date(key, args = {})
    class_parse(key, :date, Date, Patterns.date_patterns, args)
  end

  def parse_time(key, args = {})
    class_parse(key, :time, DateTime, Patterns.second_patterns, args)
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

# encoding: utf-8

class API
  attr_accessor :expected_params

  self.initializers << lambda do
    self.expected_params = {}
    parse_string(:action)
  end

  # Automatically give clients the ability to call the following parsers:
  #
  #   parse_<type>()
  #   parse_<type>s()
  #   parse_<type>_range()
  #   parse_<type>_ranges()
  #
  # Ranges are just two values separated by a dash.
  # Lists are just values separated by commas.
  # Escape dashes and commas with backslash if necessary.
  #
  def method_missing(method, *args, &block)
    if (method.to_s.match(/^(parse_\w+)s$/) and respond_to?($1)) or
       (method.to_s.match(/^((parse_\w+)_range)s$/) and respond_to?($2))
      do_parse_array($1, *args, &block)
    elsif method.to_s.match(/^(parse_\w+)_range$/) and respond_to?($1)
      do_parse_range($1, *args, &block)
    else
      super(method, *args, &block)
    end
  end

  # Parse a list of comma-separated values.  Always returns an Array if the
  # parameter was supplied, even if only one value given, else returns nil.
  def do_parse_array(method, key, args={}, &block)
    declare_parameter(key, method, args)
    str = get_param(key, :leave_slashes) or return args[:default]
    result = []
    args[:list] = true
    while str.match(/^((\\.|[^,]+)+),/)
      val, str = $1, $'
      result << send(method, val, args, &block)
    end
    result << send(method, str, args, &block)
    return result
  end

  # Parse a value or range of values (two values separated by a dash).  Returns
  # API::Range instance if range given, else parses it as a normal "scalar" value,
  # returning nil if the parameter doesn't exist.
  def do_parse_range(method, key, args={}, &block)
    declare_parameter(key, method, args)
    str = get_param(key, :leave_slashes) or return args[:default]
    args[:range] = true
    if str.match(/^((\\.|[^-]+)+)-((\\.|[^-]+)+)$/)
      val1, val2 = $1, $3
      return Range.new(send(method, val1, args, &block), send(method, val2, args, &block))
    else
      return send(method, str, args, &block)
    end
  end

  # Get value of a parameter, stripping out excess white space, and removing
  # backslashes.  Returns String if parameter was given, otherwise nil.
  def get_param(key, leave_slashes=false)
    if key.is_a?(String)
      str = key
    elsif params.has_key?(key)
      str = params[key].to_s
    else
      return nil
    end
    str = str.strip_squeeze
    str.gsub!(/\\(.)/, '\\1') unless leave_slashes
    return str
  end

  # Keep information on each parameter we attempt to parse.  We can use this
  # later to autodiscover the capabilities of each API request type.
  def declare_parameter(key, type, args)
    if key.is_a?(Symbol)
      if type.to_s.match(/^parse_/)
        type = $'.to_sym
      end
      expected_params[key] = ParameterDeclaration.new(key, type, args)
    end
  end

  def parse_boolean(key, args={})
    declare_parameter(key, :boolean, args)
    str = get_param(key) or return args[:default]
    val = case str
    when '1', 'yes', 'true' ; true
    when '0', 'no', 'false' ; false
    else
      raise BadParameterValue.new(str, :boolean)
    end
    limit = args[:limit]
    if not limit.nil? and val != limit
      raise BadLimitedParameterValue.new(str, [limit])
    end
    return val
  end

  def parse_enum_range(key, args={})
    val = do_parse_range(:parse_enum, key, args)
    if val.is_a?(Range)
      limit = args[:limit]
      if limit.index(val.begin) > limit.index(val.end)
        val.begin, val.end = val.end, val.begin
      end
    end
    return val
  end

  def parse_enum(key, args={})
    declare_parameter(key, :enum, args)
    str = get_param(key) or return args[:default]
    limit = args[:limit] or raise "missing limit!"
    for val in limit
      if str.downcase == val.to_s.downcase
        return val
      end
    end
    raise BadLimitedParameterValue.new(str, limit)
  end

  def parse_string(key, args={})
    declare_parameter(key, :string, args)
    str = get_param(key) or return args[:default]
    if limit = args[:limit]
      if str.binary_length > limit
        raise StringTooLong.new(str, limit)
      end
    end
    return str
  end

  def parse_integer(key, args={})
    declare_parameter(key, :integer, args)
    str = get_param(key) or return args[:default]
    unless str.match(/^-?\d+$/)
      raise BadParameterValue.new(str, :integer)
    end
    val = str.to_i
    if limit = args[:limit] and
       not limit.include?(val)
      raise BadLimitedParameterValue.new(str, limit)
    end
    return val
  end

  def parse_float(key, args={})
    declare_parameter(key, :float, args)
    str = get_param(key) or return args[:default]
    unless str.match(/^(-?\d+(\.\d+)?|-?\.\d+)$/)
      raise BadParameterValue.new(str, :float)
    end
    val = str.to_f
    if limit = args[:limit] and
       not limit.include?(val)
      raise BadLimitedParameterValue.new(str, limit)
    end
    return val
  end

  def parse_date(key, args={})
    declare_parameter(key, :date, args)
    str = get_param(key) or return args[:default]
    if str.match(/^\d\d\d\d[\/\-]?\d\d[\/\-]\d\d$/)
      return Date.parse(str)
    else
      raise BadParameterValue.new(str, :date)
    end
  rescue ArgumentError => e
    raise BadParameterValue.new(str, :date)
  end

  def parse_time(key, args={})
    declare_parameter(key, :time, args)
    str = get_param(key) or return args[:default]
    if str.match(/^\d\d\d\d[\/\-]?\d\d[\/\-]\d\d[ :]?\d\d:?\d\d:?\d\d$/)
      return DateTime.parse(str)
    else
      raise BadParameterValue.new(str, :time)
    end
  rescue ArgumentError => e
    raise BadParameterValue.new(str, :time)
  end

  def parse_date_range(key, args={})
    declare_parameter(key, :date_range, args)
    str = get_param(key) or return args[:default]
    if str.match(/^(\d\d\d\d[\/\-]?\d\d[\/\-]?\d\d)\s*-\s*(\d\d\d\d[\/\-]?\d\d[\/\-]?\d\d)$/)
      from, to = $1, $2
      return Range.new(
        Date.parse(from.gsub(/\D/,'')),
        Date.parse(to.gsub(/\D/,''))
      )
    elsif str.match(/^(\d\d\d\d[\/\-]?\d\d)\s*-\s*(\d\d\d\d[\/\-]?\d\d)$/)
      from, to = $1, $2
      return Range.new(
        Date.parse(from.gsub(/\D/,'') + '01'),
        Date.parse(to.gsub(/\D/,'') + '01').next_month.prev_day
      )
    elsif str.match(/^(\d\d\d\d)\s*-\s*(\d\d\d\d)$/)
      from, to = $1, $2
      return Range.new(
        Date.parse(from + '0101'),
        Date.parse(to + '0101').next_year.prev_day
      )
    elsif str.match(/^(\d\d?)\s*-\s*(\d\d?)$/)
      from, to = $1.to_i, $2.to_i
      if from < 1 or from > 12 or to < 1 or to > 12
        raise BadParameterValue.new(str, :date_range)
      end
      return Range.new( from, to )
    elsif str.match(/^\d\d\d\d[\/\-]?\d\d[\/\-]?\d\d$/)
      return Date.parse( str.gsub(/\D/,'') )
    elsif str.match(/^\d\d\d\d[\/\-]?\d\d$/)
      return Range.new(
        Date.parse( str.gsub(/\D/,'') + '01' ),
        Date.parse( str.gsub(/\D/,'') + '01' ).next_month.prev_day
      )
    elsif str.match(/^\d\d\d\d$/)
      return Range.new(
        Date.parse(str + '0101'),
        Date.parse(str + '0101').next_year.prev_day
      )
    elsif str.match(/^\d\d?$/)
      val = str.to_i
      if val < 1 or val > 12
        raise BadPA.new(str, args)
      end
      return val
    else
      raise BadParameterValue.new(str, :date_range)
    end
  rescue ArgumentError => e
    raise BadParameterValue.new(str, :date_range)
  end

  def parse_time_range(key, args={})
    declare_parameter(key, :time_range, args)
    str = get_param(key) or return args[:default]
    if str.match(/^(\d\d\d\d[\/\-]?\d\d[\/\-]?\d\d[ :]?\d\d:?\d\d:?\d\d)\s*-\s*(\d\d\d\d[\/\-]?\d\d[\/\-]?\d\d[ :]?\d\d:?\d\d:?\d\d)$/)
      from, to = $1, $2
      return Range.new(
        DateTime.parse( from.gsub(/\D/,'') ),
        DateTime.parse( to.gsub(/\D/,'') )
      )
    elsif str.match(/^(\d\d\d\d[\/\-]?\d\d[\/\-]?\d\d[ :]?\d\d:?\d\d)\s*-\s*(\d\d\d\d[\/\-]?\d\d[\/\-]?\d\d[ :]?\d\d:?\d\d)$/)
      from, to = $1, $2
      return Range.new(
        DateTime.parse( from.gsub(/\D/,'') + '01' ),
        DateTime.parse( to.gsub(/\D/,'') + '59' )
      )
    elsif str.match(/^(\d\d\d\d[\/\-]?\d\d[\/\-]?\d\d[ :]?\d\d)\s*-\s*(\d\d\d\d[\/\-]?\d\d[\/\-]?\d\d[ :]?\d\d)$/)
      from, to = $1, $2
      return Range.new(
        DateTime.parse( from.gsub(/\D/,'') + '0101' ),
        DateTime.parse( to.gsub(/\D/,'') + '5959' )
      )
    elsif str.match(/^(\d\d\d\d[\/\-]?\d\d[\/\-]?\d\d[ :]?\d\d:?\d\d:?\d\d)$/)
      return DateTime.parse( str.gsub(/\D/,'') )
    elsif str.match(/^(\d\d\d\d[\/\-]?\d\d[\/\-]?\d\d[ :]?\d\d:?\d\d)$/)
      return Range.new(
        DateTime.parse( str.gsub(/\D/,'') + '01' ),
        DateTime.parse( str.gsub(/\D/,'') + '59' )
      )
    elsif str.match(/^(\d\d\d\d[\/\-]?\d\d[\/\-]?\d\d[ :]?\d\d)$/)
      return Range.new(
        DateTime.parse( str.gsub(/\D/,'') + '0101' ),
        DateTime.parse( str.gsub(/\D/,'') + '5959' )
      )
    else
      val = parse_date_range(str, args)
      if val.is_a?(Range)
        return Range.new(
          DateTime.parse( val.begin.to_s + '010101' ),
          DateTime.parse( val.end.to_s + '235959' )
        )
      else
        return Range.new(
          DateTime.parse( val.to_s + '010101' ),
          DateTime.parse( val.to_s + '235959' )
        )
      end
    end
  rescue => e
    raise BadParameterValue.new(str, :time_range)
  end

  def parse_latitude(key, args={})
    declare_parameter(key, :latitude, args)
    str = get_param(key) or return args[:default]
    unless val = ::Location.parse_latitude(str)
      raise BadParameterValue.new(str, :latitude)
    end
    return val
  end

  def parse_longitude(key, args={})
    declare_parameter(key, :longitude, args)
    str = get_param(key) or return args[:default]
    unless val = ::Location.parse_longitude(str)
      raise BadParameterValue.new(str, :longitude)
    end
    return val
  end

  def parse_altitude(key, args={})
    declare_parameter(key, :altitude, args)
    str = get_param(key) or return args[:default]
    unless val = ::Location.parse_altitude(str)
      raise BadParameterValue.new(str, :altitude)
    end
    return val
  end

  def parse_image(key, args={})
    declare_parameter(key, :image, args)
    str = get_param(key) or return args[:default]
    val = try_parsing_id(str, ::Image)
    raise BadParameterValue.new(str, :image)
    return val
  end

  def parse_license(key, args={})
    declare_parameter(key, :license, args)
    str = get_param(key) or return args[:default]
    val = try_parsing_id(str, ::License)
    raise BadParameterValue.new(str, :license)
    return val
  end

  def parse_location(key, args={})
    declare_parameter(key, :location, args)
    str = get_param(key) or return args[:default]
    val = try_parsing_id(str, ::Location)
    val ||= ::Location.find(:first, :conditions =>
                          ['name = ? OR name = ?', str, ::Location.reverse_name(str)])
    raise BadParameterValue.new(str, :location)
    return val
  end

  def parse_place_name(key, args={})
    declare_parameter(key, :place_name, args)
    str = get_param(key) or return args[:default]
    val = try_parsing_id(str, ::Location)
    val ||= ::Location.find(:first, :conditions =>
                          ['name = ? OR name = ?', str, ::Location.reverse_name(str)])
    val = val ? val.name : str
    raise BadParameterValue.new(str, :place_name)
    return val
  end

  def parse_name(key, args={})
    declare_parameter(key, :name, args)
    str = get_param(key) or return args[:default]
    val = try_parsing_id(str, ::Name)
    unless val
      val = ::Name.find(:all, :conditions => ['(text_name = ? OR search_name = ?) AND deprecated IS FALSE', str, str])
      if val.empty?
        val = ::Name.find(:all, :conditions => ['text_name = ? OR search_name = ?', str, str])
      end
      raise BadParameterValue.new(str, :name)
      raise AmbiguousName.new(str, val) if val.length > 1
      val = val.first
    end
    if args[:correct_spelling] and
       val.correct_spelling
      val = val.correct_spelling
    end
    return val
  end

  def parse_observation(key, args={})
    declare_parameter(key, :observation, args)
    str = get_param(key) or return args[:default]
    val = try_parsing_id(str, ::Observation)
    raise BadParameterValue.new(str, :observation)
    return val
  end

  def parse_project(key, args={})
    declare_parameter(key, :project, args)
    str = get_param(key) or return args[:default]
    val = try_parsing_id(str, ::Project)
    val ||= ::Project.find_by_title(str)
    raise BadParameterValue.new(str, :project)
    return val
  end

  def parse_species_list(key, args={})
    declare_parameter(key, :species_list, args)
    str = get_param(key) or return args[:default]
    val = try_parsing_id(str, ::SpeciesList)
    val ||= ::SpeciesList.find_by_title(str)
    raise BadParameterValue.new(str, :species_list)
    return val
  end

  def parse_user(key, args={})
    declare_parameter(key, :user, args)
    str = get_param(key) or return args[:default]
    val = try_parsing_id(str, ::User)
    val ||= ::User.find(:first, :conditions => ['login = ? OR name = ?', str, str])
    raise BadParameterValue.new(str, :user)
    return val
  end

  def try_parsing_id(str, model)
    val = nil
    if str.match(/^\d+$/)
      val = model.safe_find(str)
      raise ObjectNotFound.new(str, model) if !val
    end
    return val
  end

  def parse_object(key, args={})
    declare_parameter(key, :object, args)
    str = get_param(key) or return args[:default]
    unless args.has_key?(:limit)
      raise "missing limit!"
    end
    if str.match(/^(\w+) #?(\d+)$/)
      type, id = $1, $2
      for model in args[:limit]
        if type.downcase.to_sym == model.type_tag
          val = model.safe_find(id)
          return val if val
          raise ObjectNotFound.new(str, model)
        end
      end
    end
    raise BadParameterValue.new(str, :object)
  end

  def done_parsing_parameters!
    unused = params.keys - expected_params.keys
    if unused.include?(:help)
      raise HelpMessage.new(expected_params)
    elsif unused.any?
      raise UnusedParameters.new(unused)
    end
  end

  class Range
    attr_accessor :begin, :end

    def initialize(from, to)
      if (from > to rescue false)
        from, to = to, from
      end
      @begin, @end = from, to
    end

    def include?(val)
      val >= @begin and val <= @end
    end

    def inspect
      "#{@begin.inspect}..#{@end.inspect}"
    end
  end

  class ParameterDeclaration
    attr_accessor :key, :type, :args

    def initialize(key, type, args={})
      self.key  = key
      self.type = type
      self.args = args
    end

    def inspect
      "#{key}: #{type} #{args.inspect}"
    end
  end
end

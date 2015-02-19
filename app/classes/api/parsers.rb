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
      return Range.new(send(method, val1, args, &block), send(method, val2, args, &block), args[:leave_order])
    else
      return send(method, str, args, &block)
    end
  end

  # Get value of a parameter, stripping out excess white space, and removing
  # backslashes.  Returns String if parameter was given, otherwise nil.
  def get_param(key, leave_slashes=false)
    if key.is_a?(String)
      # used when parse_range or parse_array calls parse_subtype
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
      expected_params[key] ||= ParameterDeclaration.new(key, type, args)
    end
  end

  # Simplified "parser" for getting the HTTP request -- this is passed in
  # specially by ApiController: it should not be processed in any way.
  def parse_upload
    declare_parameter(:upload, :upload, {})
    params[:upload]
  end

  def parse_boolean(key, args={})
    declare_parameter(key, :boolean, args)
    str = get_param(key) or return args[:default]
    val = case str.downcase
    when '1', 'yes', 'true', :yes.l ; true
    when '0', 'no', 'false', :no.l ; false
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
        val = Range.new(val.end, val.begin)
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

  def parse_lang(key, args={})
    declare_parameter(key, :lang, args)
    locale = get_param(key) or return Language.official.locale
    lang = Language.lang_from_locale(locale)
    langs = Language.all.map(&:locale)
    for val in langs
      if lang.downcase == val.to_s.downcase
        return val
      end
    end
    raise BadLimitedParameterValue.new(lang, langs)
  end

  def parse_string(key, args={})
    declare_parameter(key, :string, args)
    str = get_param(key) or return args[:default]
    if limit = args[:limit]
      if str.bytesize > limit
        raise StringTooLong.new(str, limit)
      end
    end
    return str
  end

  def parse_email(key, args={})
    declare_parameter(key, :email, args)
    val = parse_string(key, args)
    if val and not val.match(/^[\w\-]+@[\w\-]+(\.[\w\-]+)+$/)
      raise BadParameterValue.new(val, :email)
    end
    return val
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
    if str.match(/^\d\d\d\d\d\d\d\d$/) or
       str.match(/^\d\d\d\d-\d\d?-\d\d?$/) or
       str.match(/^\d\d\d\d\/\d\d?\/\d\d?$/)
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
    if str.match(/^\d\d\d\d\d\d\d\d\d\d\d\d\d\d$/) or
       str.match(/^\d\d\d\d-\d\d?-\d\d? \d\d?:\d\d?:\d\d?$/) or
       str.match(/^\d\d\d\d\/\d\d?\/\d\d? \d\d?:\d\d?:\d\d?$/)
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
    if str.match(/^(\d\d\d\d\d\d\d\d)\s*-\s*(\d\d\d\d\d\d\d\d)$/) or
       str.match(/^(\d\d\d\d-\d\d?-\d\d?)\s*-\s*(\d\d\d\d-\d\d?-\d\d?)$/) or
       str.match(/^(\d\d\d\d\/\d\d?\/\d\d?)\s*-\s*(\d\d\d\d\/\d\d?\/\d\d?)$/)
      from, to = $1, $2
      return Range.new(
        Date.parse(from),
        Date.parse(to)
      )
    elsif str.match(/^(\d\d\d\d\d\d)\s*-\s*(\d\d\d\d()\d\d)$/) or
          str.match(/^(\d\d\d\d-\d\d?)\s*-\s*(\d\d\d\d(-)\d\d?)$/) or
          str.match(/^(\d\d\d\d\/\d\d?)\s*-\s*(\d\d\d\d(\/)\d\d?)$/)
      from, to, sep = $1, $2, $3
      from2 = Date.parse(from + sep + '01')
      to2 = Date.parse(to + sep + '01').next_month.prev_day
      if from2 > to2
        from2 = Date.parse(to + sep + '01')
        to2 = Date.parse(from + sep + '01').next_month.prev_day
      end
      return Range.new(from2, to2)
    elsif str.match(/^(\d\d\d\d)\s*-\s*(\d\d\d\d)$/) and $1 > '1500' and $2 > '1500'
      from, to = $1, $2
      from, to = to, from if from > to
      return Range.new(
        Date.parse(from + '0101'),
        Date.parse(to + '0101').next_year.prev_day
      )
    elsif str.match(/^(\d\d)(\d\d)\s*-\s*(\d\d)(\d\d)$/) or
          str.match(/^(\d\d?)-(\d\d?)\s*-\s*(\d\d?)-(\d\d?)$/) or
          str.match(/^(\d\d?)\/(\d\d?)\s*-\s*(\d\d?)\/(\d\d?)$/)
      m1,d1, m2,d2 = $1.to_i, $2.to_i, $3.to_i, $4.to_i
      if m1 < 1 or m1 > 12 or m2 < 1 or m2 > 12 or
         d1 < 1 or d1 > 31 or d2 < 1 or d2 > 31
        raise BadParameterValue.new(str, :date_range)
      end
      return Range.new( m1*100+d1, m2*100+d2, :leave_order )
    elsif str.match(/^(\d\d?)\s*-\s*(\d\d?)$/)
      from, to = $1.to_i, $2.to_i
      if from < 1 or from > 12 or to < 1 or to > 12
        raise BadParameterValue.new(str, :date_range)
      end
      return Range.new( from, to, :leave_order )
    elsif str.match(/^\d\d\d\d\d\d\d\d$/) or
          str.match(/^\d\d\d\d-\d\d?-\d\d?$/) or
          str.match(/^\d\d\d\d\/\d\d?\/\d\d?$/)
      return Date.parse(str)
    elsif str.match(/^\d\d\d\d()\d\d$/) or
          str.match(/^\d\d\d\d(-)\d\d?$/) or
          str.match(/^\d\d\d\d(\/)\d\d?$/)
      return Range.new(
        Date.parse(str + $1 + '01'),
        Date.parse(str + $1 + '01').next_month.prev_day
      )
    elsif str.match(/^\d\d\d\d$/) and str > '1500'
      return Range.new(
        Date.parse(str + '0101'),
        Date.parse(str + '0101').next_year.prev_day
      )
    elsif str.match(/^(\d\d?)(\d\d?)$/) or
          str.match(/^(\d\d?)-(\d\d?)$/) or
          str.match(/^(\d\d?)\/(\d\d?)$/)
      m, d = $1.to_i, $2.to_i
      if m < 1 or m > 12 or
         d < 1 or d > 31
        raise BadParameterValue.new(str, :date_range)
      end
      return Range.new(m*100+d, m*100+d)
    elsif str.match(/^\d\d?$/)
      val = str.to_i
      if val < 1 or val > 12
        raise BadParameterValue.new(str, :date_range)
      end
      return Range.new(val, val)
    else
      raise BadParameterValue.new(str, :date_range)
    end
  rescue ArgumentError => e
    raise BadParameterValue.new(str, :date_range)
  end

  def parse_time_range(key, args={})
    declare_parameter(key, :time_range, args)
    str = get_param(key) or return args[:default]
    if str.match(/^(\d\d\d\d\d\d\d\d\d\d\d\d\d\d)\s*-\s*(\d\d\d\d\d\d\d\d\d\d\d\d\d\d)$/) or
       str.match(/^(\d\d\d\d-\d\d?-\d\d? \d\d?:\d\d?:\d\d?)\s*-\s*(\d\d\d\d-\d\d?-\d\d? \d\d?:\d\d?:\d\d?)$/) or
       str.match(/^(\d\d\d\d\/\d\d?\/\d\d? \d\d?:\d\d?:\d\d?)\s*-\s*(\d\d\d\d\/\d\d?\/\d\d? \d\d?:\d\d?:\d\d?)$/)
      from, to = $1, $2
      return Range.new(
        DateTime.parse(from),
        DateTime.parse(to),
      )
    elsif str.match(/^(\d\d\d\d\d\d\d\d\d\d\d\d)\s*-\s*(\d\d\d\d\d\d\d\d\d\d\d\d)$/) or
          str.match(/^(\d\d\d\d-\d\d?-\d\d? \d\d?:\d\d?)\s*-\s*(\d\d\d\d-\d\d?-\d\d? \d\d?:\d\d?)$/) or
          str.match(/^(\d\d\d\d\/\d\d?\/\d\d? \d\d?:\d\d?)\s*-\s*(\d\d\d\d\/\d\d?\/\d\d? \d\d?:\d\d?)$/)
      from, to = $1, $2
      sep = from.match(/\D/) ? ':' : ''
      from2 = DateTime.parse(from + sep + '01')
      to2 = DateTime.parse(to + sep + '59')
      if from2 > to2
        from2 = DateTime.parse(to + sep + '01')
        to2 = DateTime.parse(from + sep + '59')
      end
      return Range.new(from2, to2)
    elsif str.match(/^(\d\d\d\d\d\d\d\d\d\d)\s*-\s*(\d\d\d\d\d\d\d\d\d\d)$/) or
          str.match(/^(\d\d\d\d-\d\d?-\d\d? \d\d?)\s*-\s*(\d\d\d\d-\d\d?-\d\d? \d\d?)$/) or
          str.match(/^(\d\d\d\d\/\d\d?\/\d\d? \d\d?)\s*-\s*(\d\d\d\d\/\d\d?\/\d\d? \d\d?)$/)
      from, to = $1, $2
      sep = from.match(/\D/) ? ':' : ''
      from2 = DateTime.parse(from + sep + '01' + sep + '01')
      to2 = DateTime.parse(to + sep + '59' + sep + '59')
      if from2 > to2
        from2 = DateTime.parse(to + sep + '01' + sep + '01')
        to2 = DateTime.parse(from + sep + '59' + sep + '59')
      end
      return Range.new(from2, to2)
    elsif str.match(/^(\d\d\d\d\d\d\d\d\d\d\d\d\d\d)$/) or
          str.match(/^(\d\d\d\d-\d\d?-\d\d? \d\d?:\d\d?:\d\d?)$/) or
          str.match(/^(\d\d\d\d\/\d\d?\/\d\d? \d\d?:\d\d?:\d\d?)$/)
      return DateTime.parse(str)
    elsif str.match(/^(\d\d\d\d\d\d\d\d\d\d\d\d)$/) or
          str.match(/^(\d\d\d\d-\d\d?-\d\d? \d\d?:\d\d?)$/) or
          str.match(/^(\d\d\d\d\/\d\d?\/\d\d? \d\d?:\d\d?)$/)
      sep = str.match(/\D/) ? ':' : ''
      return Range.new(
        DateTime.parse(str + sep + '01'),
        DateTime.parse(str + sep + '59')
      )
    elsif str.match(/^(\d\d\d\d\d\d\d\d\d\d)$/) or
          str.match(/^(\d\d\d\d-\d\d?-\d\d? \d\d?)$/) or
          str.match(/^(\d\d\d\d\/\d\d?\/\d\d? \d\d?)$/)
      sep = str.match(/\D/) ? ':' : ''
      return Range.new(
        DateTime.parse(str + sep + '01' + sep + '01' ),
        DateTime.parse(str + sep + '59' + sep + '59' )
      )
    else
      val = parse_date_range(str, args)
      if val.is_a?(Range)
        return Range.new(
          DateTime.parse( val.begin.to_s + ' 01:01:01' ),
          DateTime.parse( val.end.to_s + ' 23:59:59' )
        )
      else
        return Range.new(
          DateTime.parse( val.to_s + ' 01:01:01' ),
          DateTime.parse( val.to_s + ' 23:59:59' )
        )
      end
    end
  rescue => e
    raise BadParameterValue.new(str, :time_range)
  end

  def parse_latitude(key, args={})
    declare_parameter(key, :latitude, args)
    str = get_param(key) or return args[:default]
    unless val = Location.parse_latitude(str)
      raise BadParameterValue.new(str, :latitude)
    end
    return val
  end

  def parse_longitude_range(key, args={})
    do_parse_range(:parse_longitude, key, args.merge(:leave_order => true))
  end

  def parse_longitude(key, args={})
    declare_parameter(key, :longitude, args)
    str = get_param(key) or return args[:default]
    unless val = Location.parse_longitude(str)
      raise BadParameterValue.new(str, :longitude)
    end
    return val
  end

  def parse_altitude(key, args={})
    declare_parameter(key, :altitude, args)
    str = get_param(key) or return args[:default]
    unless val = Location.parse_altitude(str)
      raise BadParameterValue.new(str, :altitude)
    end
    return val
  end

  def parse_herbarium(key, args={})
    declare_parameter(key, :herbarium, args)
    str = get_param(key) or return args[:default]
    raise BadParameterValue.new(str, :herbarium) if str.blank?
    val = try_parsing_id(str, Herbarium)
    val ||= Herbarium.find_by_name(str) ||
            Herbarium.find_by_code(str)
    raise ObjectNotFoundByString.new(str, Herbarium) if !val
    check_edit_permission!(val, args)
    return val
  end

  def parse_image(key, args={})
    declare_parameter(key, :image, args)
    str = get_param(key) or return args[:default]
    val = try_parsing_id(str, Image)
    raise BadParameterValue.new(str, :image) if !val
    check_edit_permission!(val, args)
    return val
  end

  def parse_license(key, args={})
    declare_parameter(key, :license, args)
    str = get_param(key) or return args[:default]
    val = try_parsing_id(str, License)
    raise BadParameterValue.new(str, :license) if !val
    return val
  end

  def parse_location(key, args={})
    declare_parameter(key, :location, args)
    str = get_param(key) or return args[:default]
    raise BadParameterValue.new(str, :location) if str.blank?
    val = try_parsing_id(str, Location)
    val ||= Location.find_by_name_or_reverse_name(str)
    raise ObjectNotFoundByString.new(str, Location) if !val
    return val
  end

  def parse_place_name(key, args={})
    declare_parameter(key, :place_name, args)
    str = get_param(key) or return args[:default]
    raise BadParameterValue.new(str, :location) if str.blank?
    val = try_parsing_id(str, Location)
    val ||= Location.find_by_name_or_reverse_name(str)
    return val ? val.display_name : str
  end

  def parse_name(key, args={})
    declare_parameter(key, :name, args)
    str = get_param(key) or return args[:default]
    raise BadParameterValue.new(str, :name) if str.blank?
    val = try_parsing_id(str, Name)
    if not val
      # val = Name.find(:all, :conditions => ['(text_name = ? OR search_name = ?) AND deprecated IS FALSE', str, str]) # Rails 3
      val = Name.where("deprecated IS FALSE
                        AND (text_name = ? OR search_name = ?)", str, str)
      if val.empty?
        # val = Name.find(:all, :conditions => ['text_name = ? OR search_name = ?', str, str]) # Rails 3
        val = Name.where("text_name = ? OR search_name = ?", str, str)
      end
      if val.empty?
        raise NameDoesntParse.new(str) if !Name.parse_name(str)
        raise ObjectNotFoundByString.new(str, Name)
      end
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
    val = try_parsing_id(str, Observation)
    raise BadParameterValue.new(str, :observation) if !val
    check_edit_permission!(val, args)
    return val
  end

  def parse_project(key, args={})
    declare_parameter(key, :project, args)
    str = get_param(key) or return args[:default]
    raise BadParameterValue.new(str, :project) if str.blank?
    val = try_parsing_id(str, Project)
    val ||= Project.find_by_title(str)
    raise ObjectNotFoundByString.new(str, Project) if !val
    check_if_admin!(val, args)
    check_if_member!(val, args)
    return val
  end

  def parse_species_list(key, args={})
    declare_parameter(key, :species_list, args)
    str = get_param(key) or return args[:default]
    raise BadParameterValue.new(str, :species_list) if str.blank?
    val = try_parsing_id(str, SpeciesList)
    val ||= SpeciesList.find_by_title(str)
    raise ObjectNotFoundByString.new(str, SpeciesList) if !val
    check_edit_permission!(val, args)
    return val
  end

  def parse_user(key, args={})
    declare_parameter(key, :user, args)
    str = get_param(key) or return args[:default]
    raise BadParameterValue.new(str, :user) if str.blank?
    val = try_parsing_id(str, User)
    # val ||= User.find(:first, :conditions => ['login = ? OR name = ?', str, str]) # Rails 3
    val ||= User.where("login = ? OR name = ?", str, str).first
    raise ObjectNotFoundByString.new(str, User) if !val
    check_edit_permission!(val, args)
    return val
  end

  def try_parsing_id(str, model)
    obj = nil
    if str.match(/^\d+$/)
      obj = model.safe_find(str)
      raise ObjectNotFoundById.new(str, model) if !obj
    end
    return obj
  end

  def check_edit_permission!(obj, args)
    if args[:must_have_edit_permission] and
       not obj.has_edit_permission?(@user)
      raise MustHaveEditPermission.new(obj)
    end
  end

  def check_if_admin!(proj, args)
    if args[:must_be_admin] and
       not @user.projects_admin.include?(proj)
      raise MustBeAdmin.new(proj)
    end
  end

  def check_if_member!(proj, args)
    if args[:must_be_member] and
       not @user.projects_member.include?(proj)
      raise MustBeMember.new(proj)
    end
  end

  def parse_object(key, args={})
    declare_parameter(key, :object, args)
    str = get_param(key) or return args[:default]
    unless args.has_key?(:limit)
      raise "missing limit!"
    end
    if not str.match(/^([a-z][ _a-z]*[a-z]) #?(\d+)$/i)
      raise BadParameterValue.new(str, :object)
    end
    type, id = $1, $2
    type = type.gsub(' ','_').downcase
    val = nil
    for model in args[:limit]
      if model.type_tag.to_s == type
        break if val = model.safe_find(id)
        raise ObjectNotFoundById.new(str, model)
      end
    end
    raise BadLimitedParameterValue.new(str, args[:limit].map(&:type_tag)) if !val
    check_edit_permission!(val, args)
    return val
  end

  def done_parsing_parameters!
    unused = params.keys - expected_params.keys
    if unused.include?(:help)
      raise HelpMessage.new(expected_params)
    else
      if unused.include?(:upload)
        raise UnexpectedUpload.new
        unused.delete(:upload)
      end
      if unused.any?
        raise UnusedParameters.new(unused)
      end
    end
  end

  class Range
    attr_accessor :begin, :end

    def initialize(from, to, leave_order=false)
      unless leave_order
        if ( from.is_a?(AbstractModel) ? from.id > to.id : from > to rescue false )
          from, to = to, from
        end
      end
      @begin, @end = from, to
    end

    def include?(val)
      val >= @begin and val <= @end
    end

    def inspect
      "#{@begin.inspect}..#{@end.inspect}"
    end

    alias to_s inspect

    def ==(other)
      other.is_a?(Range) and
      other.begin == self.begin and
      other.end == self.end
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

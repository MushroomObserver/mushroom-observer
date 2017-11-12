# API
class API
  attr_accessor :expected_params

  initializers << lambda do
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
    submethod = parse_method(method, /^(parse_\w+)s$/) ||
                parse_method(method, /^((parse_\w+)_range)s$/, 2)
    return do_parse_array(submethod, *args, &block) if submethod
    submethod = parse_method(method, /^(parse_\w+)_range$/)
    return do_parse_range(submethod, *args, &block) if submethod
    super
  end

  def respond_to_missing?(method, include_private = false)
    parse_method(method, /^(parse_\w+)s$/) ||
      parse_method(method, /^((parse_\w+)_range)s$/, 2) ||
      parse_method(method, /^(parse_\w+)_range$/) ||
      super
  end

  def parse_method(method, pattern, test_match = 1, return_match = 1)
    match = method.to_s.match(pattern)
    return match[return_match] if match && respond_to?(match[test_match])
  end

  # Parse a list of comma-separated values.  Always returns an Array if the
  # parameter was supplied, even if only one value given, else returns nil.
  def do_parse_array(method, key, args = {}, &block)
    declare_parameter(key, method, args)
    str = get_param(key, :leave_slashes)
    return args[:default] unless str
    result = []
    args[:list] = true
    while (match = str.match(/^((\\.|[^,]+)+),/))
      str = match.post_match
      result << send(method, match[1], args, &block)
    end
    result << send(method, str, args, &block)
  end

  # Parse a value or range of values (two values separated by a dash).
  # Returns OrderedRange instance if range given, else parses it as a
  # normal "scalar" value, returning nil if the parameter doesn't
  # exist.
  def do_parse_range(method, key, args = {}, &block)
    declare_parameter(key, method, args)
    str = get_param(key, :leave_slashes)
    return args[:default] unless str
    args[:range] = true
    match = str.match(/^((\\.|[^-]+)+)-((\\.|[^-]+)+)$/)
    return send(method, str, args, &block) unless match
    OrderedRange.new(send(method, match[1], args, &block),
                     send(method, match[3], args, &block),
                     args[:leave_order])
  end

  # Get value of a parameter, stripping out excess white space, and removing
  # backslashes.  Returns String if parameter was given, otherwise nil.
  def get_param(key, leave_slashes = false)
    return clean_param(key, leave_slashes) if key.is_a?(String)
    return clean_param(params[key].to_s, leave_slashes) if params.key?(key)
  end

  def clean_param(str, leave_slashes)
    result = str.strip_squeeze
    result.gsub!(/\\(.)/, "\\1") unless leave_slashes
    result
  end

  # Keep information on each parameter we attempt to parse.  We can use this
  # later to autodiscover the capabilities of each API request type.
  def declare_parameter(key, type, args)
    return unless key.is_a?(Symbol)
    match = type.to_s.match(/^parse_(.*)/)
    type = match[1].to_sym if match
    expected_params[key] ||= ParameterDeclaration.new(key, type, args)
  end

  # Simplified "parser" for getting the HTTP request -- this is passed in
  # specially by ApiController: it should not be processed in any way.
  def parse_upload
    declare_parameter(:upload, :upload, {})
    params[:upload]
  end

  def try_parsing_id(str, model)
    return nil unless str =~ /^\d+$/
    obj = model.safe_find(str)
    return obj if obj
    raise ObjectNotFoundById.new(str, model)
  end

  def check_edit_permission!(obj, args)
    return unless args[:must_have_edit_permission]
    raise MustHaveEditPermission.new(obj) unless obj.has_edit_permission?(@user)
  end

  def done_parsing_parameters!
    unused = params.keys - expected_params.keys
    raise HelpMessage.new(expected_params)          if unused.include?(:help)
    raise UnexpectedUpload.new("Unexpected upload") if unused.include?(:upload)
    raise UnusedParameters.new(unused)              if unused.any?
  end
end

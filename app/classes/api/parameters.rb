# API
class API
  attr_accessor :expected_params
  attr_accessor :ignore_params

  initializers << lambda do
    self.expected_params = {}
    self.ignore_params   = {}
    parse(:string, :action)
  end

  def parse(*args, &block)
    parser(*args).parse_scalar(&block)
  end

  def parse_range(*args, &block)
    parser(*args).parse_range(&block)
  end

  def parse_ranges(*args, &block)
    parser(*args).parse_array(:parse_range, &block)
  end

  def parse_array(*args, &block)
    parser(*args).parse_array(:parse_scalar, &block)
  end

  # Simplified "parser" for getting the HTTP request -- this is passed in
  # specially by ApiController: it should not be processed in any way.
  def parse_upload
    expected_params[:upload] ||= ParameterDeclaration.new(:upload, :upload, {})
    params[:upload]
  end

  # These are the parameters which will show up in the help message.
  def declare_parameter(key, type, args = {})
    expected_params[key] ||= ParameterDeclaration.new(key, type, args)
    expected_params[key].set_parameter = true if @mark_the_rest_as_set_params
  end

  # This tells declare_parameter to mark all the rest of the parameters
  # as "set" parameters.  Useful for separating "get" and "set" parameters
  # in the help message.
  def mark_the_rest_as_set_params
    @mark_the_rest_as_set_params = true
  end

  # These parameters will be ignored in the help message.
  def ignore_parameter(key)
    ignore_params[key] = nil
  end

  # These parameters should be omitted from the help message.
  def deprecate_parameter(key)
    expected_params[key].deprecated = true
  end

  def done_parsing_parameters!
    unused = params.keys - expected_params.keys - ignore_params.keys
    raise HelpMessage.new(expected_params) if unused.include?(:help)
    raise UnexpectedUpload.new             if unused.include?(:upload)
    raise UnusedParameters.new(unused)     if unused.any?
  end

  # ------------------------------------------
  #  These validators belong elsewhere.
  #  They are shared by multiple model apis.
  # ------------------------------------------

  def make_sure_location_isnt_dubious!(name)
    return if name.blank? || Location.where(name: name).any?

    citations =
      Location.check_for_empty_name(name) +
      Location.check_for_dubious_commas(name) +
      Location.check_for_bad_country_or_state(name) +
      Location.check_for_bad_terms(name) +
      Location.check_for_bad_chars(name)
    return if citations.none?

    raise DubiousLocationName.new(citations)
  end

  def parse_bounding_box!
    n = parse(:latitude, :north, help: 1)
    s = parse(:latitude, :south, help: 1)
    e = parse(:longitude, :east, help: 1)
    w = parse(:longitude, :west, help: 1)
    return unless n || s || e || w
    return [n, s, e, w] if n && s && e && w

    raise NeedAllFourEdges.new
  end

  ##############################################################################

  private

  def parser(type, key, args = {})
    "API::Parsers::#{type.to_s.camelize}Parser".constantize.new(self, key, args)
  end
end

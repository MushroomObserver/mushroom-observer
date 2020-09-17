# frozen_string_literal: true

# API2
class API2
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
    raise(HelpMessage.new(expected_params)) if unused.include?(:help)
    raise(UnexpectedUpload.new)             if unused.include?(:upload)
    raise(UnusedParameters.new(unused))     if unused.any?
  end

  ##############################################################################

  private

  def parser(type, key, args = {})
    "API2::Parsers::#{type.to_s.camelize}Parser".constantize.new(self, key, args)
  end
end

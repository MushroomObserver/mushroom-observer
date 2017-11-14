# API
class API
  attr_accessor :expected_params

  initializers << lambda do
    self.expected_params = {}
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

  def parser(type, key, args = {})
    "API::Parsers::#{type.to_s.camelize}Parser".constantize.new(self, key, args)
  end

  # Simplified "parser" for getting the HTTP request -- this is passed in
  # specially by ApiController: it should not be processed in any way.
  def parse_upload
    expected_params[:upload] ||= ParameterDeclaration.new(:upload, :upload, {})
    params[:upload]
  end

  def done_parsing_parameters!
    unused = params.keys - expected_params.keys
    raise HelpMessage.new(expected_params)          if unused.include?(:help)
    raise UnexpectedUpload.new("Unexpected upload") if unused.include?(:upload)
    raise UnusedParameters.new(unused)              if unused.any?
  end
end

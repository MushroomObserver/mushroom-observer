# frozen_string_literal: true

# API2
module API2::Parameters
  # Information about an API parameter to provide automatic documentation
  class ParameterDeclaration
    attr_accessor :key, :type, :args, :set_parameter, :deprecated

    def initialize(key, type, args = {})
      self.key  = key
      self.type = type
      self.args = args
    end

    def set_parameter?
      @set_parameter
    end

    def deprecated?
      @deprecated
    end

    def inspect
      "#{key}: #{show_type}#{show_args}"
    end

    def show_type
      val = type.to_s
      val += " range" if args[:range]
      val += " list"  if args[:list]
      val
    end

    def show_args
      hash = args.except(:as, :list, :range)
      hash.delete(:default) if hash[:default].to_s == ""
      if /^\d+$/.match?(hash[:limit].to_s)
        hash[:limit] = "#{hash[:limit]} chars"
      end
      return "" if hash.empty?

      body = hash.map { |key, val| show_arg(key, val) }.join(", ")
      " (#{body})"
    end

    def show_arg(key, val)
      key = key.to_s.tr("_", " ")
      if key == "help"
        val = @key if val == 1
        tag = :"api_help_#{val}"
        tag.l
      elsif key != "limit" && val == true
        key
      else
        "#{key}=#{show_val(val)}"
      end
    end

    def show_val(val)
      case val
      when String, Symbol, Integer, Float, Range
        val.to_s
      when Array
        val.map(&:to_s).sort.join("|")
      when TrueClass
        "true"
      when FalseClass
        "false"
      when Date, License
        "varies"
      when Name
        val.search_name
      when User
        "you"
      else
        raise("Don't know how to display #{val.class.name} in api help msg.")
      end
    end
  end

  def parse(*, &block)
    parser(*).parse_scalar(&block)
  end

  def parse_range(*, &block)
    parser(*).parse_range(&block)
  end

  def parse_ranges(*, &block)
    parser(*).parse_array(:parse_range, &block)
  end

  def parse_array(*, &block)
    parser(*).parse_array(:parse_scalar, &block)
  end

  # Simplified "parser" for getting the HTTP request -- this is passed in
  # specially by API2Controller: it should not be processed in any way.
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
    raise(API2::HelpMessage.new(expected_params)) if unused.include?(:help)
    raise(API2::UnexpectedUpload.new)             if unused.include?(:upload)
    raise(API2::UnusedParameters.new(unused))     if unused.any?
  end

  ##############################################################################

  private

  def parser(type, key, args = {})
    klass = "API2::Parsers::#{type.to_s.camelize}Parser".constantize
    klass.new(self, key, args)
  end
end

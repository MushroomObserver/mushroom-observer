# frozen_string_literal: true

class API
  module Parsers
    # API parser base class.
    class Base
      attr_accessor :api
      attr_accessor :key
      attr_accessor :args

      def initialize(api, key, args)
        @api  = api
        @key  = key
        @args = args
        @val  = key.is_a?(Symbol) ? api.params[key] : key
        api.declare_parameter(key, type, args)
      end

      def type
        self.class.name.sub(/.*::/, "").sub(/Parser$/, "").underscore.to_sym
      end

      def parse_scalar
        str = clean_param
        return args[:default] unless str

        val = parse(str)
        return val unless val.blank? && args[:not_blank]

        raise ParameterCantBeBlank.new(key)
      end

      # Parse a list of comma-separated values.  Always returns an Array if the
      # parameter was supplied, even if only one value given, else returns nil.
      def parse_array(parse_scalar_or_range)
        args[:list] = true
        str = clean_param(:leave_slashes)
        return args[:default] if str.blank?

        result = []
        while (match = str.match(/^((\\.|[^\\,]+)+),/))
          str = match.post_match
          @val = match[1]
          result << send(parse_scalar_or_range)
        end
        @val = str
        result << send(parse_scalar_or_range)
      end

      # Parse a value or range of values (two values separated by a dash).
      # Returns OrderedRange instance if range given, else parses it as a
      # normal "scalar" value, returning nil if the parameter doesn't exist.
      def parse_range
        args[:range] = true
        str = clean_param(:leave_slashes)
        return args[:default] if str.blank?

        match = str.match(/^((\\.|[^\\-]+)+)-((\\.|[^\\-]+)+)$/)
        if match
          @val = match[1]
          from = parse_scalar
          @val = match[3]
          to   = parse_scalar
        else
          from = to = parse_scalar
        end
        ordered_range(from, to)
      end

      def ordered_range(from, to)
        OrderedRange.new(from, to)
      end

      # Get value of parameter, strip out excess white space, and removing
      # backslashes.  Returns String if parameter was given, otherwise nil.
      def clean_param(leave_slashes = false)
        return unless @val

        val = @val.to_s.strip
        val.gsub!(/\\(.)/, "\\1") unless leave_slashes
        val
      end
    end
  end
end

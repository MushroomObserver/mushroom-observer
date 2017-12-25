class API
  module Parsers
    # Parse floats for API.
    class FloatParser < Base
      FLOAT = /^(-?\d+(\.\d+)?|-?\.\d+)$/

      def parse(str)
        raise BadParameterValue.new(str, :float) unless str =~ FLOAT
        val = str.to_f
        limit = args[:limit]
        return val if !limit || limit.include?(val)
        raise BadLimitedParameterValue.new(str, limit)
      end

      # Reduce trivial ranges to just a single value.
      def parse_range
        val = super || return
        val.begin == val.end ? val.begin : val
      end
    end
  end
end

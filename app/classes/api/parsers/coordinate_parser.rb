class API
  module Parsers
    # Parse lat/longs and altitudes for API.
    class CoordinateParser < Base
      def parse(type, str)
        Location.send("parse_#{type}", str) ||
          raise(BadParameterValue.new(str, type))
      end

      # Reduce trivial ranges to just a single value.
      def parse_range
        val = super || return
        val.begin == val.end ? val.begin : val
      end
    end
  end
end

# frozen_string_literal: true

class API2
  module Parsers
    # Parse latitudes for API2.
    class LatitudeParser < CoordinateParser
      def parse(str)
        super(:latitude, str)
      end
    end
  end
end

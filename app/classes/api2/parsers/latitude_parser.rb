# frozen_string_literal: true

class API2
  module Parsers
    # Parse latitudes for API.
    class LatitudeParser < CoordinateParser
      def parse(str)
        super(:latitude, str)
      end
    end
  end
end

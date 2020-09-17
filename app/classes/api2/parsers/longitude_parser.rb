# frozen_string_literal: true

class API2
  module Parsers
    # Parse longitudes for API2.
    class LongitudeParser < CoordinateParser
      def parse(str)
        super(:longitude, str)
      end
    end
  end
end

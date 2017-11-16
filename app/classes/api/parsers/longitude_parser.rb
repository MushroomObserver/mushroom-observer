class API
  module Parsers
    # Parse longitudes for API.
    class LongitudeParser < CoordinateParser
      def parse(str)
        super(:longitude, str)
      end
    end
  end
end

class API
  module Parsers
    # Parse API longitudes
    class LongitudeParser < CoordinateParser
      def parse(str)
        super(:longitude, str)
      end
    end
  end
end

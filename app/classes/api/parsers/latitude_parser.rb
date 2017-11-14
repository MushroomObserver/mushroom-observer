class API
  module Parsers
    # Parse API latitudes
    class LatitudeParser < CoordinateParser
      def parse(str)
        super(:latitude, str)
      end
    end
  end
end

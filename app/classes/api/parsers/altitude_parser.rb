class API
  module Parsers
    # Parse API altitudes
    class AltitudeParser < CoordinateParser
      def parse(str)
        super(:altitude, str)
      end
    end
  end
end

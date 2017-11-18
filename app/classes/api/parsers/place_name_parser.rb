class API
  module Parsers
    # Parse place names for API.
    class PlaceNameParser < LocationParser
      def parse(str)
        val = super
        val.is_a?(Location) ? val.display_name : str
      rescue ObjectNotFoundByString
        str
      end
    end
  end
end

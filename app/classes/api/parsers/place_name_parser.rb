class API
  module Parsers
    # Parse API place names
    class PlaceNameParser < LocationParser
      def parse(str)
        val = super
        val.is_a?(Location) ? val.display_name : val
      rescue ObjectNotFoundByString
        str
      end
    end
  end
end

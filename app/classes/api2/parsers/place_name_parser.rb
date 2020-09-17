# frozen_string_literal: true

class API2
  module Parsers
    # Parse place names for API2.
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

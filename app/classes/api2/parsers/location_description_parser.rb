# frozen_string_literal: true

class API2
  module Parsers
    # Parse location_descriptions for API.
    class LocationDescriptionParser < ObjectBase
      def model
        LocationDescription
      end
    end
  end
end

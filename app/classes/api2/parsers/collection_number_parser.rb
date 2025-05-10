# frozen_string_literal: true

class API2
  module Parsers
    # Parse collection_numbers for API.
    class CollectionNumberParser < ObjectBase
      def model
        CollectionNumber
      end
    end
  end
end

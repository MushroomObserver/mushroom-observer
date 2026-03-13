# frozen_string_literal: true

class API2
  module Parsers
    # Parse name_descriptions for API.
    class NameDescriptionParser < ObjectBase
      def model
        NameDescription
      end
    end
  end
end

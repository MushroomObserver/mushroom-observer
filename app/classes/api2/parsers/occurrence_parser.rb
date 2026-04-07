# frozen_string_literal: true

class API2
  module Parsers
    # Parse occurrences for API.
    class OccurrenceParser < ObjectBase
      def model
        Occurrence
      end
    end
  end
end

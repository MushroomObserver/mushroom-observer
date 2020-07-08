# frozen_string_literal: true

class API
  module Parsers
    # Parse observations for API.
    class ObservationParser < ObjectBase
      def model
        Observation
      end
    end
  end
end

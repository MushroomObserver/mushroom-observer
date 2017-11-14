class API
  module Parsers
    # Parse API observations
    class ObservationParser < ObjectBase
      def model
        Observation
      end
    end
  end
end

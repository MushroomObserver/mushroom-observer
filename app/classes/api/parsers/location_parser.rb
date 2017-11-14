class API
  module Parsers
    # Parse API locations
    class LocationParser < ObjectBase
      def model
        Location
      end

      def try_finding_by_string(str)
        Location.find_by_name_or_reverse_name(str)
      end
    end
  end
end

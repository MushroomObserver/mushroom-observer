class API
  module Parsers
    # Parse specimens for API.
    class SpecimenParser < ObjectBase
      def model
        Specimen
      end

      def try_finding_by_string(str)
        Specimen.find_by_herbarium_label(str)
      end
    end
  end
end

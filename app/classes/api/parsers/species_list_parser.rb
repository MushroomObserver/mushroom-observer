class API
  module Parsers
    # Parse API species lists
    class SpeciesListParser < ObjectBase
      def model
        SpeciesList
      end

      def try_finding_by_string(str)
        SpeciesList.find_by_title(str)
      end
    end
  end
end

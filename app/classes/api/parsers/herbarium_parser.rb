# frozen_string_literal: true

class API
  module Parsers
    # Parse herbaria for API.
    class HerbariumParser < ObjectBase
      def model
        Herbarium
      end

      def try_finding_by_string(str)
        Herbarium.find_by_name(str) || Herbarium.find_by_code(str)
      end
    end
  end
end

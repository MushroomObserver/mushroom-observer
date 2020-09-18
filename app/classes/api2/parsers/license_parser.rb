# frozen_string_literal: true

class API2
  module Parsers
    # Parse licenses for API.
    class LicenseParser < ObjectBase
      def model
        License
      end
    end
  end
end

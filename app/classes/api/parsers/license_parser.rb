# frozen_string_literal: true

class API
  module Parsers
    # Parse licenses for API.
    class LicenseParser < ObjectBase
      def model
        License
      end
    end
  end
end

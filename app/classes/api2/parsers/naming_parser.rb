# frozen_string_literal: true

class API2
  module Parsers
    # Parse namings for API.
    class NamingParser < ObjectBase
      def model
        Naming
      end
    end
  end
end

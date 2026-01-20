# frozen_string_literal: true

class API2
  module Parsers
    # Parse field_slips for API.
    class FieldSlipParser < ObjectBase
      def model
        FieldSlip
      end
    end
  end
end

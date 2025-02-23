# frozen_string_literal: true

class API2
  module Parsers
    # Parse sequences for API.
    class SequenceParser < ObjectBase
      def model
        Sequence
      end
    end
  end
end

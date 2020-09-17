# frozen_string_literal: true

class API2
  module Parsers
    # Parse confidences for API.
    class ConfidenceParser < FloatParser
      def initialize(*args)
        super
        self.args[:limit] = Range.new(Vote.minimum_vote, Vote.maximum_vote)
      end
    end
  end
end

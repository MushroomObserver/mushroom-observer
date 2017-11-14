class API
  module Parsers
    # Parse API confidences
    class ConfidenceParser < FloatParser
      def initialize(*args)
        super
        self.args[:limit] = Range.new(Vote.minimum_vote, Vote.maximum_vote)
      end
    end
  end
end

# frozen_string_literal: true

class API2
  module Parsers
    # Parse qualities for API2.
    class QualityParser < FloatParser
      def initialize(*args)
        super
        self.args[:limit] = Range.new(Image.minimum_vote, Image.maximum_vote)
      end
    end
  end
end

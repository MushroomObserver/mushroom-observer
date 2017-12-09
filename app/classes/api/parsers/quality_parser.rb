class API
  module Parsers
    # Parse qualities for API.
    class QualityParser < FloatParser
      def initialize(*args)
        super
        self.args[:limit] = Range.new(Image.minimum_vote, Image.maximum_vote)
      end
    end
  end
end

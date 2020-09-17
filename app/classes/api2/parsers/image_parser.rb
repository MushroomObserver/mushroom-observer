# frozen_string_literal: true

class API2
  module Parsers
    # Parse images for API2.
    class ImageParser < ObjectBase
      def model
        Image
      end
    end
  end
end

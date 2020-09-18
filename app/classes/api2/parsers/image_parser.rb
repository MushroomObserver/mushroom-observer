# frozen_string_literal: true

class API2
  module Parsers
    # Parse images for API.
    class ImageParser < ObjectBase
      def model
        Image
      end
    end
  end
end

# frozen_string_literal: true

class API2
  module Parsers
    # Parse comments for API.
    class CommentParser < ObjectBase
      def model
        Comment
      end
    end
  end
end

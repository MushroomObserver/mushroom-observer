# frozen_string_literal: true

class API2
  module Parsers
    # Parse external_links for API.
    class ExternalLinkParser < ObjectBase
      def model
        ExternalLink
      end
    end
  end
end

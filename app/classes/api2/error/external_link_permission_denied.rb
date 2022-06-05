# frozen_string_literal: true

class API2
  # Request to post external link requires certain permissions.
  class ExternalLinkPermissionDenied < Error
  end
end
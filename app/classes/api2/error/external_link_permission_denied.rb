# frozen_string_literal: true

class API2
  # Request to post external link requires certain permissions.
  class ExternalLinkPermissionDenied < FatalError
  end
end

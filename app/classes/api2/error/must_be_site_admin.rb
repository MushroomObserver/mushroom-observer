# frozen_string_literal: true

class API2
  # Request requires a site administrator's API key.
  class MustBeSiteAdmin < FatalError
  end
end

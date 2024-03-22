# frozen_string_literal: true

class API2
  # Request requires valid APIKey.
  class MustAuthenticate < FatalError
  end
end

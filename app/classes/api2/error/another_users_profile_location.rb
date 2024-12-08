# frozen_string_literal: true

class API2
  # Cannot update location if another user has made it their profile location.
  class AnotherUsersProfileLocation < FatalError
  end
end

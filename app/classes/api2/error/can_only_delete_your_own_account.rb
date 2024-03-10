# frozen_string_literal: true

class API2
  # Attempted to delete someone else's account.
  class CanOnlyDeleteYourOwnAccount < FatalError
  end
end

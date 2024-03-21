# frozen_string_literal: true

class API2
  # Error thrown when PATCH or DELETE abort from errors before doing anything.
  class AbortDueToErrors < FatalError
  end
end

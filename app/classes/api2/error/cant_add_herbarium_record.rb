# frozen_string_literal: true

class API2
  # Tried to add herbarium record to observation that you don't own, and you
  # are not a curator of the herbarium.
  class CantAddHerbariumRecord < FatalError
  end
end

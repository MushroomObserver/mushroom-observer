# frozen_string_literal: true

class API2
  # Tried to update name of more than one location at once.
  class TryingToSetMultipleLocationsToSameName < FatalError
  end
end

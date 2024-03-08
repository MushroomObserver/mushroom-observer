# frozen_string_literal: true

class API2
  # Tried to update name/author/rank of more than one name at once.
  class TryingToSetMultipleNamesAtOnce < FatalError
  end
end

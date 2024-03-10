# frozen_string_literal: true

class API2
  # Tried to set herbarium_record info without claiming specimen present.
  class CanOnlyUseThisFieldIfHasSpecimen < FatalError
    def initialize(field)
      super()
      args.merge!(field: field)
    end
  end
end

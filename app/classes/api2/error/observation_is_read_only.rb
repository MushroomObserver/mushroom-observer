# frozen_string_literal: true

class API2
  # Attempted to edit a read-only reflection of an imported observation
  # (#4214). Change it at the source and resync instead.
  class ObservationIsReadOnly < ObjectError
  end
end

# frozen_string_literal: true

class API2
  # Attempted to view something that requires view permission.
  class MustHaveViewPermission < ObjectError
  end
end
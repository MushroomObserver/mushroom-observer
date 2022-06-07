# frozen_string_literal: true

class API2
  # Attempted to alter something that requires edit permission.
  class MustHaveEditPermission < ObjectError
  end
end

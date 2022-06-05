# frozen_string_literal: true

class API2
  # Attempted to add object you don't own to a project.
  class MustBeOwner < ObjectError
  end
end
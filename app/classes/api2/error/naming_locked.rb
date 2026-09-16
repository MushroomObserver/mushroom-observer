# frozen_string_literal: true

class API2
  # Attempted to edit or delete a Naming after another user has already
  # voted on it.
  class NamingLocked < ObjectError
  end
end

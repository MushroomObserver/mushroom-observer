# frozen_string_literal: true

class API2
  # Request requires you to be project member.
  class MustBeMember < ObjectError
  end
end
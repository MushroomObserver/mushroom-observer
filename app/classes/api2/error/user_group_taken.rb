# frozen_string_literal: true

class API2
  # Tried to create a user group that already exists.
  class UserGroupTaken < FatalError
    def initialize(title)
      super()
      args.merge!(title: title.to_s)
    end
  end
end

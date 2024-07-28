# frozen_string_literal: true

class API2
  # Tried to create project that already exists.
  class ProjectTaken < FatalError
    def initialize(title)
      super()
      args.merge!(title: title.to_s)
    end
  end
end

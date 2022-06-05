# frozen_string_literal: true

class API2
  # Request requires you to be project admin.
  class MustBeAdmin < Error
    def initialize(proj)
      super()
      args.merge!(project: proj.title)
    end
  end
end
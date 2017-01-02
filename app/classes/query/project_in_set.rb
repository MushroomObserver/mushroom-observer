module Query
  # Projects in a given set.
  class ProjectInSet < Query::ProjectBase
    def parameter_declarations
      super.merge(
        ids: [Project]
      )
    end

    def initialize_flavor
      initialize_in_set_flavor("projects")
      super
    end
  end
end

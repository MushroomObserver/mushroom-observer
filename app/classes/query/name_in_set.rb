module Query
  # Names in a given set.
  class NameInSet < Query::NameBase
    def parameter_declarations
      super.merge(
        ids: [Name]
      )
    end

    def initialize_flavor
      initialize_in_set_flavor("names")
      super
    end
  end
end

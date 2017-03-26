module Query
  # Locations in a given set.
  class LocationInSet < Query::LocationBase
    def parameter_declarations
      super.merge(
        ids: [Location]
      )
    end

    def initialize_flavor
      initialize_in_set_flavor("locations")
      super
    end
  end
end

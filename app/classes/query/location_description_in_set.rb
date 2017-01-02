module Query
  # Location descriptions in a given set.
  class LocationDescriptionInSet < Query::LocationDescriptionBase
    def parameter_declarations
      super.merge(
        ids:     [LocationDescription],
        old_by?: :string
      )
    end

    def initialize_flavor
      initialize_in_set_flavor("location_descriptions")
      super
    end

    def coerce_into_location_query
      Query.lookup(:Location, :with_descriptions_in_set, params_plus_old_by)
    end
  end
end

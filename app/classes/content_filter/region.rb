class ContentFilter
  # Content filter to restrict observations and locations to just one region.
  class Region < StringFilter
    def initialize
      super(
        sym:    :region,
        models: [Observation, Location]
      )
    end

    def sql_conditions(query, model, val)
      val = Location.reverse_name_if_necessary(val)
      expr = make_regexp(query, val)
      field = (model == Location) ? "locations.name" : "observations.where"
      "CONCAT(', ', #{field}) #{expr}"
    end

    def make_regexp(query, val)
      if Location.understood_continent?(val)
        vals = Location.countries_in_continent(val).join("|")
        "REGEXP " + query.escape(", (#{vals})$")
      else
        "LIKE " + query.escape("%, #{val}")
      end
    end
  end
end

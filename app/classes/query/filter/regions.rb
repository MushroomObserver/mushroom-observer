# frozen_string_literal: true

class Query::Filter
  # Content filter restricting observations or locations to one or more regions.
  # Inheriting from StringFilter means multiple values joined by OR conditions.
  class Regions < StringFilter
    def initialize
      super(
        sym: :regions,
        name: :REGION,
        models: [Observation, Location]
      )
    end

    def sql_condition(query, model, val)
      val = Location.reverse_name_if_necessary(val)
      expr = make_regexp(query, val)
      field = model == Location ? "locations.name" : "observations.where"
      "CONCAT(', ', #{field}) #{expr}"
    end

    def make_regexp(query, val)
      if Location.understood_continent?(val)
        vals = Location.countries_in_continent(val).join("|")
        "REGEXP #{query.escape(", (#{vals})$")}"
      else
        "LIKE #{query.escape("%, #{val}")}"
      end
    end
  end
end

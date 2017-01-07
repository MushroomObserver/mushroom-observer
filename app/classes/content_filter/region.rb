# encoding: utf-8
class ContentFilter
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
      if model == Observation
        [sql_conditions_for_observations(expr)]
      else
        [sql_conditions_for_locations(expr)]
      end
    end

    def sql_conditions_for_observations(expr)
      %(
        IF(
          observations.location_id IS NOT NULL,
          observations.location_id IN (
            SELECT id FROM locations WHERE CONCAT(', ', name) #{expr}
          ),
          CONCAT(', ', observations.where) #{expr}
        )
      )
    end

    def sql_conditions_for_locations(expr)
      "CONCAT(', ', locations.name) #{expr}"
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

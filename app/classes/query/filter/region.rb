# frozen_string_literal: true

class Query::Filter
  # Content filter restricting observations or locations to one or more regions.
  # Inheriting from StringFilter means multiple values joined by OR conditions.
  class Region < StringFilter
    def initialize
      super(
        sym: :region,
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

    # The "+" is an arel extensions operator
    # rubocop:disable Style/StringConcatenation
    def scope_condition(query, model, val)
      val = Location.reverse_name_if_necessary(val)
      concat = if model == Location
                 Location[:name] + ", "
               else
                 Observation[:where] + ", "
               end
      make_scope_regexp(query, concat, val)
    end
    # rubocop:enable Style/StringConcatenation

    def make_scope_regexp(query, concat, val)
      if Location.understood_continent?(val)
        vals = Location.countries_in_continent(val).join("|")
        # "REGEXP #{query.escape(", (#{vals})$")}"
        concat =~ query.escape(", (#{vals})$")
      else
        # "LIKE #{query.escape("%, #{val}")}"
        concat.matches(query.escape("%, #{val}"))
      end
    end
  end
end

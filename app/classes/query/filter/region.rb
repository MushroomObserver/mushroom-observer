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
  end
end

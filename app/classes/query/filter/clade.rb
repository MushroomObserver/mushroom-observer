# frozen_string_literal: true

class Query::Filter
  # Content filter to restrict observations and names to taxonomic clade/s.
  # Inheriting from StringFilter means multiple values joined by OR conditions.
  class Clade < StringFilter
    def initialize
      super(
        sym: :clade,
        name: :CLADE,
        models: [Observation, Name]
      )
    end
  end
end

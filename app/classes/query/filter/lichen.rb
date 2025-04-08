# frozen_string_literal: true

class Query::Filter
  # Content filter specifically to filter out or just show lichens.
  class Lichen < BooleanFilter
    def initialize
      super(
        sym: :lichen,
        name: :LICHEN,
        models: [Observation, Name],
        on_vals: %w[no yes],
        prefs_vals: %w[no yes],
        off_val: nil
      )
    end
  end
end

# frozen_string_literal: true

class Query::Filter
  class WithOccurrence < BooleanFilter
    def initialize
      super(
        sym: :has_occurrence,
        name: :OCCURRENCE,
        models: [Observation],
        on_vals: %w[yes no],
        prefs_vals: [],
        off_val: nil
      )
    end
  end
end

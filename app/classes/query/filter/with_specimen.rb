# frozen_string_literal: true

class Query::Filter
  class WithSpecimen < BooleanFilter
    def initialize
      super(
        sym: :has_specimen,
        name: :SPECIMEN,
        models: [Observation],
        on_vals: %w[yes no],
        prefs_vals: ["yes"],
        off_val: nil
      )
    end
  end
end

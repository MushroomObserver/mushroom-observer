# frozen_string_literal: true

class Query::Filter
  class WithSpecimen < BooleanFilter
    def initialize
      super(
        sym: :with_specimen,
        name: :SPECIMEN.t,
        models: [Observation],
        on_vals: %w[yes no],
        prefs_vals: ["yes"],
        off_val: nil
      )
    end

    def sql_conditions(_query, _model, val)
      ["observations.specimen IS #{val ? "TRUE" : "FALSE"}"]
    end
  end
end

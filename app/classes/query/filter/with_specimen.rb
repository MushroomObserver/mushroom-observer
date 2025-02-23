# frozen_string_literal: true

class Query::Filter
  class WithSpecimen < BooleanFilter
    def initialize
      super(
        sym: :with_specimen,
        name: :SPECIMEN,
        models: [Observation],
        on_vals: %w[yes no],
        prefs_vals: ["yes"],
        off_val: nil
      )
    end

    def sql_conditions(_query, _model, val)
      ["observations.specimen IS #{val ? "TRUE" : "FALSE"}"]
    end

    def scope_conditions(_query, _model, val)
      if val.present?
        Observation[:specimen].eq(true)
      else
        Observation[:specimen].eq(false)
      end
    end
  end
end

# frozen_string_literal: true

class Query::Filter
  class WithImages < BooleanFilter
    def initialize
      super(
        sym: :has_images,
        name: :IMAGES,
        models: [Observation],
        on_vals: %w[yes no],
        prefs_vals: ["yes"],
        off_val: nil
      )
    end

    def sql_conditions(_query, _model, val)
      ["observations.thumb_image_id IS #{val ? "NOT NULL" : "NULL"}"]
    end
  end
end

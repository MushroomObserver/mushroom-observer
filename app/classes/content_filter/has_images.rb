# encoding: utf-8
class ContentFilter
  class HasImages < BooleanFilter
    def initialize
      super(
        sym:         :has_images,
        models:      [Observation],
        on_vals:     ["yes", "no"],
        prefs_vals:  ["yes"],
        off_val:     nil
      )
    end

    def sql_conditions(query, model, val)
      ["observations.thumb_image_id IS #{val ? "NOT NULL" : "NULL"}"]
    end
  end
end

# encoding: utf-8
class ContentFilter
  class Lichen < BooleanFilter
    def initialize
      super(
        sym:         :lichen,
        models:      [Observation, Name],
        on_vals:     ["no", "yes"],
        prefs_vals:  ["no", "yes"],
        off_val:     nil
      )
    end

    def sql_conditions(query, model, val)
      # Note the critical difference -- the extra spaces in the negative
      # version.  This allows all lifeforms containing the word "lichen" to be
      # selected for in the positive version, but only excudes the one lifeform
      # in the negative. 
      cond = val ? "names.lifeform LIKE '%lichen%'" :
                   "names.lifeform NOT LIKE '% lichen %'"
      return cond if model == Name
      "observations.name_id IN (SELECT id FROM names WHERE #{cond})"
    end
  end
end

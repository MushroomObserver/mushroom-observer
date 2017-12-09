# encoding: utf-8
class ContentFilter
  class Clade < StringFilter
    def initialize
      super(
        sym:    :clade,
        models: [Observation, Name]
      )
    end

    def sql_conditions(query, model, val)
      name, rank = parse_name(val)
      cond = Name.ranks_above_genus.include?(rank) ?
               "names.classification REGEXP '#{rank}: _#{name}_'" :
               "names.text_name REGEXP '^#{name} '"
      cond = "text_name = '#{name}' OR #{cond}"
      return cond if model == Name
      "observations.name_id IN (SELECT id FROM names WHERE #{cond})"
    end

    def parse_name(val)
      name = Name.best_match(val)
      return [name.text_name, name.rank] if name
      [val, Name.guess_rank(val) || :Genus]
    end
  end
end

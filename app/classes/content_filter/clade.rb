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
      table = (model == Name) ? "names" : "observations"
      name, rank = parse_name(val)
      "#{table}.text_name = '#{name}' OR " +
        (Name.ranks_above_genus.include?(rank) ?
        "#{table}.classification REGEXP '#{rank}: _#{name}_'" :
        "#{table}.text_name REGEXP '^#{name} '")
    end

    def parse_name(val)
      name = Name.best_match(val)
      return [name.text_name, name.rank] if name
      [val, Name.guess_rank(val) || :Genus]
    end
  end
end

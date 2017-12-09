# encoding: utf-8
class ContentFilter
  class Clade < StringFilter
    def initialize
      super(
        sym:    :clade,
        models: [Observation]
      )
    end

    def sql_conditions(query, model, val)
      name, rank = parse_name(val)
      expr = Name.ranks_above_genus.include?(rank) ?
        "names.classification REGEXP '#{rank}: _#{name}_'" :
        "names.text_name REGEXP '^#{name} '"
      %(
        observations.name_id IN (
          SELECT id FROM names WHERE text_name = '#{name}' OR #{expr}
        )
      )
    end

    def parse_name(val)
      name = Name.best_match(val)
      return [name.text_name, name.rank] if name
      [val, Name.guess_rank(val) || :Genus]
    end
  end
end

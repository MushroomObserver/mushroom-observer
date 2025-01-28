# frozen_string_literal: true

class Query::Filter
  # Content filter to restrict observations and names to a taxonomic clade.
  class Clade < StringFilter
    def initialize
      super(
        sym: :clade,
        name: :CLADE.t,
        models: [Observation, Name]
      )
    end

    def sql_condition(_query, model, val)
      table = model == Name ? "names" : "observations"
      name, rank = parse_name(val)
      if Name.ranks_above_genus.include?(rank)
        "#{table}.text_name = '#{name}' OR " \
        "#{table}.classification REGEXP '#{rank}: _#{name}_'"
      else
        "#{table}.text_name = '#{name}' OR " \
        "#{table}.text_name REGEXP '^#{name} '"
      end
    end

    def scope_condition(model, val)
      name, rank = parse_name(val)
      if Name.ranks_above_genus.include?(rank)
        # "#{table}.text_name = '#{name}' OR " \
        # "#{table}.classification REGEXP '#{rank}: _#{name}_'"
        condition_matching_classification(model, name, rank)
      else
        # "#{table}.text_name = '#{name}' OR " \
        # "#{table}.text_name REGEXP '^#{name} '"
        condition_matching_text_name_only(model, name)
      end
    end

    def condition_matching_classification(model, name, rank)
      model.arel_table[:text_name].eq(name).
        or(model.arel_table[:text_name] =~ "#{rank}: _#{name}_")
    end

    def condition_matching_text_name_only(model, name)
      model.arel_table[:text_name].eq(name).
        or(model.arel_table[:text_name] =~ "^#{name} ")
    end

    def parse_name(val)
      name = Name.best_match(val)
      return [name.text_name, name.rank] if name

      [val, Name.guess_rank(val) || "Genus"]
    end
  end
end

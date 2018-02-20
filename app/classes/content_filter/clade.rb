class ContentFilter
  # Content filter to restrict observations and names to a taxonomic clade.
  class Clade < StringFilter
    def initialize
      super(
        sym:    :clade,
        models: [Observation, Name]
      )
    end

    def sql_conditions(query, model, val)
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

    def parse_name(val)
      name = Name.best_match(val)
      return [name.text_name, name.rank] if name
      [val, Name.guess_rank(val) || :Genus]
    end
  end
end

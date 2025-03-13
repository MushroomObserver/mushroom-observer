# frozen_string_literal: true

class Query::Filter
  # Content filter to restrict observations and names to taxonomic clade/s.
  # Inheriting from StringFilter means multiple values joined by OR conditions.
  class Clades < StringFilter
    def initialize
      super(
        sym: :clades,
        name: :CLADE,
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

    def parse_name(val)
      name = Name.best_match(val)
      return [name.text_name, name.rank] if name

      [val, Name.guess_rank(val) || "Genus"]
    end
  end
end

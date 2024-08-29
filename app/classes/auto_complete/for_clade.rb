# frozen_string_literal: true

class AutoComplete::ForClade < AutoComplete::ByString
  def rough_matches(letter)
    # (this sort puts higher rank on top)
    clades = Name.with_correct_spelling.with_rank_above_genus.
             where(Name[:text_name].matches("#{letter}%")).order(rank: :desc).
             select(:text_name, :rank, :id, :deprecated)

    matches_array(clades)
  end

  # Doesn't make sense to have exact match for clades
  # def exact_match(string)
  #   clade = Name.with_correct_spelling.with_rank_above_genus.
  #           where(Name[:text_name].eq(string)).first
  #   return [] unless clade

  #   matches_array([clade])
  # end

  # Turn the instances into hashes
  def matches_array(clades)
    matches = clades.map do |clade|
      clade = clade.attributes.symbolize_keys
      clade[:deprecated] = clade[:deprecated] || false
      clade[:name] = clade[:text_name]
      clade.except(:text_name, :rank)
    end
    matches.sort_by! { |clade| clade[:name] }
    matches.uniq { |clade| clade[:name] }
  end
end

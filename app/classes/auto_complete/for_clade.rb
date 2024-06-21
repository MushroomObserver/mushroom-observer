# frozen_string_literal: true

class AutoComplete::ForClade < AutoComplete::ByString
  def rough_matches(letter)
    # (this sort puts higher rank on top)
    clades = Name.with_correct_spelling.with_rank_above_genus.
             where(Name[:text_name].matches("#{letter}%")).order(rank: :desc).
             select(:text_name, :rank, :id, :deprecated).
             pluck(:text_name, :id, :deprecated).uniq(&:first)

    clades.map! do |name, id, deprecated|
      { name: name, id: id, deprecated: deprecated || false }
    end
    clades.sort_by! { |clade| clade[:name] }
  end
end

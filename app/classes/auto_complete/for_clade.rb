# frozen_string_literal: true

class AutoComplete::ForClade < AutoComplete::ByString
  def rough_matches(letter)
    # (this sort puts higher rank on top)
    Name.with_correct_spelling.with_rank_above_genus.
      where(Name[:text_name].matches("#{letter}%")).order(rank: :desc).
      select(:text_name, :rank, :id).pluck(:text_name, :id).uniq
  end
end

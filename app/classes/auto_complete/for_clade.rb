# frozen_string_literal: true

class AutoComplete::ForClade < AutoComplete::ByString
  def rough_matches(letter)
    # (this sort puts higher rank on top)
    Name.with_correct_spelling.with_rank_above_genus.
      where(Name[:text_name].matches("#{letter}%")).order(rank: :desc).
      select(:text_name, :rank).map(&:text_name).uniq
  end
end

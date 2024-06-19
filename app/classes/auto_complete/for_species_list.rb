# frozen_string_literal: true

class AutoComplete::ForSpeciesList < AutoComplete::ByWord
  def rough_matches(letter)
    SpeciesList.select(:title, :id).distinct.
      where(SpeciesList[:title].matches("#{letter}%").
        or(SpeciesList[:title].matches("% #{letter}%"))).
      order(title: :asc).pluck(:title, :id)
  end
end

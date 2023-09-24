# frozen_string_literal: true

class AutoCompleteSpeciesList < AutoCompleteByWord
  def rough_matches(letter)
    SpeciesList.select(:title).distinct.
      where(SpeciesList[:title].matches("#{letter}%").
        or(SpeciesList[:title].matches("% #{letter}%"))).
      order(title: :asc).pluck(:title)
  end
end

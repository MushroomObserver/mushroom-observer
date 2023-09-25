# frozen_string_literal: true

class AutoComplete::ForProject < AutoComplete::ByWord
  def rough_matches(letter)
    Project.select(:title).distinct.
      where(Project[:title].matches("#{letter}%").
        or(Project[:title].matches("% #{letter}%"))).
      order(title: :asc).pluck(:title)
  end
end

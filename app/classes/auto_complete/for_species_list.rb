# frozen_string_literal: true

class AutoComplete::ForSpeciesList < AutoComplete::ByWord
  def rough_matches(letter)
    lists = SpeciesList.select(:title, :id).distinct.
            where(SpeciesList[:title].matches("#{letter}%").
              or(SpeciesList[:title].matches("% #{letter}%"))).
            order(title: :asc).pluck(:title, :id)

    lists.map! { |name, id| { name:, id: } }
  end
end

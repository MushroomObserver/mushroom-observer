# frozen_string_literal: true

class AutoComplete::ForSpeciesList < AutoComplete::ByWord
  def rough_matches(letter)
    lists = SpeciesList.select(:title, :id).distinct.
            where(SpeciesList[:title].matches("#{letter}%").
              or(SpeciesList[:title].matches("% #{letter}%"))).
            order(title: :asc)

    # Turn the instances into hashes, and alter title key
    lists.map do |list|
      list = list.attributes.symbolize_keys
      { name: list[:title], id: list[:id] }
    end
    # matches.sort_by! { |list| list[:name] }
  end
end

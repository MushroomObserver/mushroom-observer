# frozen_string_literal: true

class Autocomplete::ForSpeciesList < Autocomplete::ByWord
  def rough_matches(letter)
    lists = SpeciesList.select(:title, :id).distinct.
            where(SpeciesList[:title].matches("#{letter}%").
              or(SpeciesList[:title].matches("% #{letter}%"))).
            order(title: :asc)

    matches_array(lists)
  end

  def exact_match(string)
    list = SpeciesList.select(:title, :id).distinct.
           where(SpeciesList[:title].eq(string)).first
    return [] unless list

    matches_array([list])
  end

  # Turn the instances into hashes, and alter title key
  def matches_array(lists)
    lists.map do |list|
      list = list.attributes.symbolize_keys
      { name: strip_textile(list[:title]), id: list[:id] }
    end
    # matches.sort_by! { |list| list[:name] }
  end

  # Remove textile formatting characters (* and _) from string
  def strip_textile(str)
    str.gsub(/[_*]/, "")
  end
end

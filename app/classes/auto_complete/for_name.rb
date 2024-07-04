# frozen_string_literal: true

class AutoComplete::ForName < AutoComplete::ByString
  def rough_matches(letter)
    names = Name.with_correct_spelling.
            select(:text_name, :id, :deprecated).distinct.
            where(Name[:text_name].matches("#{letter}%"))

    # Turn the instances into hashes, and format the deprecated field
    matches = names.map do |name|
      name = name.attributes.symbolize_keys
      name[:deprecated] = name[:deprecated] || false
      name[:name] = name[:text_name]
      name.delete(:text_name) # faster than `except`
      name
    end
    # This sort puts genera and higher on top, everything else on bottom,
    # and sorts alphabetically within each group, and non-deprecated dups first
    matches.sort_by! do |name|
      [(name[:name].match?(" ") ? "b" : "a") + name[:name], name[:deprecated]]
    end
    matches.uniq { |name| name[:name] }
  end
end

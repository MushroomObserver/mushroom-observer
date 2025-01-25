# frozen_string_literal: true

class Autocomplete::ForName < Autocomplete::ByString
  def rough_matches(letter)
    names = Name.with_correct_spelling.
            select(:text_name, :id, :deprecated).distinct.
            where(Name[:text_name].matches("#{letter}%"))

    matches_array(names)
  end

  def exact_match(string)
    name = Name.with_correct_spelling.
           select(:text_name, :id, :deprecated).distinct.
           where(Name[:text_name].eq(string)).first
    return [] unless name

    matches_array([name])
  end

  # Turn the instances into hashes, and format the deprecated field
  def matches_array(names)
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
      [(name[:name].match?(" ") ? "b" : "a") + name[:name],
       name[:deprecated].to_i]
    end
    matches.uniq { |name| name[:name] }
  end
end

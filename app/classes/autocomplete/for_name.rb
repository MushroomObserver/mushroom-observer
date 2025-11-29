# frozen_string_literal: true

class Autocomplete::ForName < Autocomplete::ByString
  # Minimum characters before switching from beginning-match to word-match
  WORD_MATCH_THRESHOLD = 4

  def rough_matches(letter)
    names = Name.with_correct_spelling.
            select(:text_name, :id, :deprecated).distinct.
            where(name_match_condition(letter))

    matches_array(names)
  end

  private

  # Returns Arel condition for matching names.
  # Short queries (< WORD_MATCH_THRESHOLD): match beginning of name only
  # Longer queries: match beginning of any word in the name
  def name_match_condition(letter)
    beginning_match = Name[:text_name].matches("#{letter}%")

    if letter.length < WORD_MATCH_THRESHOLD
      beginning_match
    else
      # Match beginning of name OR beginning of any word after a space
      word_match = Name[:text_name].matches("% #{letter}%")
      beginning_match.or(word_match)
    end
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

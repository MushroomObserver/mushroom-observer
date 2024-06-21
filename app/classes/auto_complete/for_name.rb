# frozen_string_literal: true

class AutoComplete::ForName < AutoComplete::ByString
  def rough_matches(letter)
    names = Name.with_correct_spelling.
            select(:text_name, :id, :deprecated).distinct.
            where(Name[:text_name].matches("#{letter}%")).
            pluck(:text_name, :id, :deprecated)

    names.map! do |name, id, deprecated|
      dep_string = deprecated.nil? ? "false" : deprecated.to_s
      { name: name, id: id, deprecated: dep_string }
    end
    # This sort puts genera and higher on top, everything else on bottom,
    # and sorts alphabetically within each group, and non-deprecated dups first
    names.sort_by! do |name|
      [(name[:name].match?(" ") ? "b" : "a") + name[:name], name[:deprecated]]
    end
    names.uniq { |name| name[:name] }
  end
end

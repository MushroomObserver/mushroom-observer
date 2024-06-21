# frozen_string_literal: true

class AutoComplete::ForName < AutoComplete::ByString
  def rough_matches(letter)
    # (this sort puts genera and higher on top, everything else
    # on bottom, and sorts alphabetically within each group)
    names = Name.with_correct_spelling.
            select(:text_name, :id, :deprecated).distinct.
            where(Name[:text_name].matches("#{letter}%")).
            pluck(:text_name, :id, :deprecated).sort_by do |x, _id, _d|
      (x.match?(" ") ? "b" : "a") + x
    end.uniq

    names.map! do |name, id, deprecated|
      { name: name, id: id, deprecated: deprecated || false }
    end
  end
end

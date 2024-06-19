# frozen_string_literal: true

class AutoComplete::ForName < AutoComplete::ByString
  def rough_matches(letter)
    # (this sort puts genera and higher on top, everything else
    # on bottom, and sorts alphabetically within each group)
    Name.with_correct_spelling.select(:text_name).distinct.
      where(Name[:text_name].matches("#{letter}%")).
      pluck(:text_name, :id).sort_by do |x, _id|
        (x.match?(" ") ? "b" : "a") + x
      end.uniq
  end
end

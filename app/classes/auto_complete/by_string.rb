# frozen_string_literal: true

class AutoComplete::ByString < AutoComplete
  # Find minimal string whose matches are within the limit.  This is designed
  # to reduce the number of AJAX requests required if the user backspaces from
  # the end of the text field string.
  #
  # The initial query has already matched everything containing a word beginning
  # with the correct first letter.  Applies additional letters one at a time
  # until the number of matches falls below limit.
  #
  # Returns the final (minimal) [string, id] actually used, and changes matches
  # in place.  The array 'matches' is guaranteed to be <= limit.
  def refine_token
    # Get rid of trivial case immediately.
    return string[0] if matches.length <= limit

    # Apply characters in order until matches fits within limit.
    used = ""
    string.chars.each do |letter|
      used += letter
      regex = /(^|#{PUNCTUATION})#{used}/i
      matches.select! { |m, _id| m.match(regex) }
      break if matches.length <= limit
    end
    used
  end
end

# frozen_string_literal: true

class AutoComplete::ByWord < AutoComplete
  # Same as AutoCompleteByString#refine_token, except words are allowed
  # to be out of order.
  def refine_token
    # Get rid of trivial case immediately.
    return string[0] if matches&.length&.<= limit

    # Apply words in order, requiring full word-match on all but last.
    words = string.split
    used  = ""
    n     = 0
    words.each do |word|
      n += 1
      part = ""
      word.chars.each do |letter|
        part += letter
        regex = /(^|#{PUNCTUATION})#{part}/i
        matches&.select! { |obj| obj[:name].match(regex) }
        return used + part if matches&.length&.<= limit
      end
      if n < words.length
        used += "#{word} "
        regex = /(^|#{PUNCTUATION})#{word}(#{PUNCTUATION}|$)/i
        matches&.select! { |obj| obj[:name].match(regex) }
        return used if matches&.length&.<= limit
      else
        used += word
        return used
      end
    end
  end
end

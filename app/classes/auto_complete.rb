# frozen_string_literal: true

#
#  = AutoComplete base class
#
#    auto = AutoCompleteName.new('Agaricus') # ...or...
#    auto = AutoComplete.subclass('name').new('Agaricus')
#    render(:inline => auto.matching_strings.join("\n"))
#
################################################################################

PUNCTUATION = '[ -\x2F\x3A-\x40\x5B-\x60\x7B-\x7F]'

class AutoComplete
  attr_accessor :string, :matches

  class_attribute :limit
  self.limit = 1000

  def self.subclass(type)
    "AutoComplete#{type.camelize}".constantize
  rescue StandardError
    raise("Invalid auto-complete type: #{type.inspect}")
  end

  def initialize(string, _params = {})
    self.string = string.to_s.strip_squeeze
  end

  def matching_strings
    self.matches = rough_matches(string[0])
    clean_matches
    minimal_string = refine_matches
    truncate_matches
    # [minimal_string] + matches
    [[minimal_string, nil]] + matches
  end

  private

  def truncate_matches
    return unless matches.length > limit

    matches.slice!(limit..-1)
    # matches.push("...")
    matches.push(["...", nil])
  end

  def clean_matches
    # matches.map! do |str|
    #   str.sub(/\s*[\r\n]\s*.*/m, "").sub(/\A\s+/, "").sub(/\s+\Z/, "")
    # end
    matches.map! do |str, id|
      clean = str.sub(/\s*[\r\n]\s*.*/m, "").sub(/\A\s+/, "").sub(/\s+\Z/, "")
      [clean, id]
    end
    matches.uniq!
  end
end

class AutoCompleteByString < AutoComplete
  # Find minimal string whose matches are within the limit.  This is designed
  # to reduce the number of AJAX requests required if the user backspaces from
  # the end of the text field string.
  #
  # The initial query has already matched everything containing a word beginning
  # with the correct first letter.  Applies additional letters one at a time
  # until the number of matches falls below limit.
  #
  # Returns the final (minimal) string actually used, and changes matches in
  # place.  The array 'matches' is guaranteed to be <= limit.
  def refine_matches
    # Get rid of trivial case immediately.
    # return string[0] if matches.length <= limit
    return [string[0], nil] if matches.length <= limit

    # Apply characters in order until matches fits within limit.
    used = ""
    # string.chars.each do |letter|
    #   used += letter
    #   regex = /(^|#{PUNCTUATION})#{used}/i
    #   matches.select! { |m| m.match(regex) }
    #   break if matches.length <= limit
    # end
    string.chars.each do |letter|
      used += letter
      regex = /(^|#{PUNCTUATION})#{used}/i
      matches.select! { |m, id| m.match(regex) }
      break if matches.length <= limit
    end
    used
  end
end

class AutoCompleteByWord < AutoComplete
  # Same as AutoCompleteByString#refine_matches, except words are allowed
  # to be out of order.
  def refine_matches
    # Get rid of trivial case immediately.
    # return string[0] if matches.length <= limit
    return [string[0], nil] if matches.length <= limit

    # Apply words in order, requiring full word-match on all but last.
    words = string.split
    used  = ""
    n     = 0
    # words.each do |word|
    #   n += 1
    #   part = ""
    #   word.chars.each do |letter|
    #     part += letter
    #     regex = /(^|#{PUNCTUATION})#{part}/i
    #     matches.select! { |m| m.match(regex) }
    #     return used + part if matches.length <= limit
    #   end
    #   if n < words.length
    #     used += "#{word} "
    #     regex = /(^|#{PUNCTUATION})#{word}(#{PUNCTUATION}|$)/i
    #     matches.select! { |m| m.match(regex) }
    #     return used if matches.length <= limit
    #   else
    #     used += word
    #     return used
    #   end
    # end
    words.each do |word|
      n += 1
      part = ""
      word.chars.each do |letter|
        part += letter
        regex = /(^|#{PUNCTUATION})#{part}/i
        matches.select! { |m, id| m.match(regex) }
        return used + part if matches.length <= limit
      end
      if n < words.length
        used += "#{word} "
        regex = /(^|#{PUNCTUATION})#{word}(#{PUNCTUATION}|$)/i
        matches.select! { |m, id| m.match(regex) }
        return used if matches.length <= limit
      else
        used += word
        return used
      end
    end
  end
end

# Nimmo note: Is it desirable to make `rough_matches` a scope for these models?
# Doing that, plus a method to pluck the values, would solve the ABC violation.
# Any caching advantage in that? Then below, it'd be something like:
#   Observation.rough_matches(letter).pluck_matches
# Or would this scatter the code?
# Thinking the scope could be useful for graphQL, or it could use this class.
#
class AutoCompleteLocation < AutoCompleteByWord
  attr_accessor :reverse

  def initialize(string, params)
    super(string, params)
    self.reverse = (params[:format] == "scientific")
  end

  def rough_matches(letter)
    # matches =
    #   Observation.select(:where).distinct.
    #   where(Observation[:where].matches("#{letter}%").
    #     or(Observation[:where].matches("% #{letter}%"))).pluck(:where) +
    #   Location.select(:name).distinct.
    #   where(Location[:name].matches("#{letter}%").
    #     or(Location[:name].matches("% #{letter}%"))).pluck(:name)

    # matches.map! { |m| Location.reverse_name(m) } if reverse
    matches =
      Observation.select(:where, :id).distinct.
      where(Observation[:where].matches("#{letter}%").
        or(Observation[:where].matches("% #{letter}%"))).pluck(:where, :id) +
      Location.select(:name, :id).distinct.
      where(Location[:name].matches("#{letter}%").
        or(Location[:name].matches("% #{letter}%"))).pluck(:name, :id)

    matches.map! { |m, id| m == Location.reverse_name(m) } if reverse
    matches.sort.uniq
  end
end

# stimulus-autocomplete:
# Would be nicer with an array of [id, string], that way we could avoid lookup.
class AutoCompleteName < AutoCompleteByString
  def rough_matches(letter)
    # (this sort puts genera and higher on top, everything else
    # on bottom, and sorts alphabetically within each group)
    # Name.with_correct_spelling.select(:text_name).distinct.
    #   where(Name[:text_name].matches("#{letter}%")).
    #   pluck(:text_name).sort_by { |x| (x.match?(" ") ? "b" : "a") + x }.uniq
    Name.with_correct_spelling.select(:text_name, :id).distinct.
      where(Name[:text_name].matches("#{letter}%")).
      pluck(:text_name, :id).sort_by {
        |x, id| (x.match?(" ") ? "b" : "a") + x
      }.uniq
  end
end

class AutoCompleteNameAboveGenus < AutoCompleteByString
  def rough_matches(letter)
    # (this sort puts higher rank on top)
    # Name.with_correct_spelling.with_rank_above_genus.
    #   where(Name[:text_name].matches("#{letter}%")).order(rank: :desc).
    #   select(:text_name, :rank).map(&:text_name).uniq
    Name.with_correct_spelling.with_rank_above_genus.
      where(Name[:text_name].matches("#{letter}%")).order(rank: :desc).
      select(:text_name, :rank, :id).pluck(:text_name, :id).uniq
  end
end

class AutoCompleteProject < AutoCompleteByWord
  def rough_matches(letter)
    # Project.select(:title).distinct.
    #   where(Project[:title].matches("#{letter}%").
    #     or(Project[:title].matches("% #{letter}%"))).
    #   order(title: :asc).pluck(:title)
    Project.select(:title, :id).distinct.
      where(Project[:title].matches("#{letter}%").
        or(Project[:title].matches("% #{letter}%"))).
      order(title: :asc).pluck(:title, :id)
  end
end

class AutoCompleteSpeciesList < AutoCompleteByWord
  def rough_matches(letter)
    # SpeciesList.select(:title).distinct.
    #   where(SpeciesList[:title].matches("#{letter}%").
    #     or(SpeciesList[:title].matches("% #{letter}%"))).
    #   order(title: :asc).pluck(:title)
    SpeciesList.select(:title, :id).distinct.
      where(SpeciesList[:title].matches("#{letter}%").
        or(SpeciesList[:title].matches("% #{letter}%"))).
      order(title: :asc).pluck(:title, :id)
  end
end

# If sending multidimensional arrays
# to sort by string in [string, id] sort_by { |k| k[0] }
class AutoCompleteUser < AutoCompleteByString
  def rough_matches(letter)
    # users = User.select(:login, :name).distinct.
    #         where(User[:login].matches("#{letter}%").
    #           or(User[:name].matches("#{letter}%")).
    #           or(User[:name].matches("% #{letter}%"))).
    #         order(login: :asc).pluck(:login, :name)

    # users.map do |login, name|
    #   name.empty? ? login : "#{login} <#{name}>"
    # end.sort
    users = User.select(:login, :name, :id).distinct.
            where(User[:login].matches("#{letter}%").
              or(User[:name].matches("#{letter}%")).
              or(User[:name].matches("% #{letter}%"))).
            order(login: :asc).pluck(:login, :name, :id)

    users.map do |login, name, id|
      text = name.empty? ? login : "#{login} <#{name}>"
      [text, id]
    end.sort
  end
end

class AutoCompleteHerbarium < AutoCompleteByWord
  def rough_matches(letter)
    # herbaria =
    #   Herbarium.select(:code, :name).distinct.
    #   where(Herbarium[:name].matches("#{letter}%").
    #     or(Herbarium[:name].matches("% #{letter}%")).
    #     or(Herbarium[:code].matches("#{letter}%"))).
    #   order(Herbarium[:code].
    #     when(nil).then(name: :asc).else(code: :asc, name: :asc)).
    #   pluck(:code, :name)

    # herbaria.map do |code, name|
    #   code.empty? ? name : "#{code} - #{name}"
    # end.sort
    herbaria =
      Herbarium.select(:code, :name, :id).distinct.
      where(Herbarium[:name].matches("#{letter}%").
        or(Herbarium[:name].matches("% #{letter}%")).
        or(Herbarium[:code].matches("#{letter}%"))).
      order(name: :asc, id: :asc).pluck(:code, :name, :id)

    herbaria.map do |code, name, id|
      text = code.empty? ? name : "#{code} - #{name}"
      [text, id]
    end.sort
  end
end

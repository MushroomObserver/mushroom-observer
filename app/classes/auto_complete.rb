#
#  = AutoComplete base class
#
#    auto = AutoCompleteName.new('Agaricus') # ...or...
#    auto = AutoComplete.subclass('name').new('Agaricus')
#    render(:inline => auto.matching_strings.join("\n"))
#
################################################################################

PUNCTUATION = '[ -\x2F\x3A-\x40\x5B-\x60\x7B-\x7F]'.freeze

class AutoComplete
  attr_accessor :string, :matches

  class_attribute :limit
  self.limit = 1000

  def self.subclass(type)
    "AutoComplete#{type.camelize}".constantize
  rescue StandardError
    raise "Invalid auto-complete type: #{type.inspect}"
  end

  def initialize(string, _params = {})
    self.string = string.to_s.strip_squeeze
  end

  def matching_strings
    self.matches = rough_matches(string[0])
    clean_matches
    minimal_string = refine_matches
    truncate_matches
    [minimal_string] + matches
  end

  private

  def truncate_matches
    if matches.length > limit
      matches.slice!(limit..-1)
      matches.push("...")
    end
  end

  def clean_matches
    matches.map! do |str|
      str.sub(/\s*[\r\n]\s*.*/m, "").sub(/\A\s+/, "").sub(/\s+\Z/, "")
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
    return string[0] if matches.length <= limit

    # Apply characters in order until matches fits within limit.
    used = ""
    for letter in string.split("")
      used += letter
      regex = /(^|#{PUNCTUATION})#{used}/i
      matches.select! { |m| m.match(regex) }
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
    return string[0] if matches.length <= limit

    # Apply words in order, requiring full word-match on all but last.
    words = string.split
    used  = ""
    n     = 0
    for word in words
      n += 1
      part = ""
      for letter in word.split("")
        part += letter
        regex = /(^|#{PUNCTUATION})#{part}/i
        matches.select! { |m| m.match(regex) }
        return used + part if matches.length <= limit
      end
      if n < words.length
        used += word + " "
        regex = /(^|#{PUNCTUATION})#{word}(#{PUNCTUATION}|$)/i
        matches.select! { |m| m.match(regex) }
        return used if matches.length <= limit
      else
        used += word
        return used
      end
    end
  end
end

class AutoCompleteLocation < AutoCompleteByWord
  attr_accessor :reverse

  def initialize(string, params)
    super(string, params)
    self.reverse = (params[:format] == "scientific")
  end

  def rough_matches(letter)
    matches = Observation.connection.select_values(%(
      SELECT DISTINCT `where` FROM observations
      WHERE `where` LIKE '#{letter}%' OR
            `where` LIKE '% #{letter}%'
    )) + Location.connection.select_values(%(
      SELECT DISTINCT `name` FROM locations
      WHERE `name` LIKE '#{letter}%' OR
            `name` LIKE '% #{letter}%'
    ))
    matches.map! { |m| Location.reverse_name(m) } if reverse
    matches.sort.uniq
  end
end

class AutoCompleteName < AutoCompleteByString
  def rough_matches(letter)
    Name.connection.select_values(%(
      SELECT DISTINCT text_name FROM names
      WHERE text_name LIKE '#{letter}%'
      AND correct_spelling_id IS NULL
    )).sort_by { |x| (x.match?(" ") ? "b" : "a") + x }.uniq
    # (this sort puts genera and higher on top, everything else
    # on bottom, and sorts alphabetically within each group)
  end
end

class AutoCompleteProject < AutoCompleteByWord
  def rough_matches(letter)
    Project.connection.select_values(%(
      SELECT DISTINCT title FROM projects
      WHERE title LIKE '#{letter}%'
         OR title LIKE '% #{letter}%'
      ORDER BY title ASC
    ))
  end
end

class AutoCompleteSpeciesList < AutoCompleteByWord
  def rough_matches(letter)
    SpeciesList.connection.select_values(%(
      SELECT DISTINCT title FROM species_lists
      WHERE title LIKE '#{letter}%'
         OR title LIKE '% #{letter}%'
      ORDER BY title ASC
    ))
  end
end

class AutoCompleteUser < AutoCompleteByString
  def rough_matches(letter)
    User.connection.select_values(%(
      SELECT DISTINCT CONCAT(users.login, IF(users.name = "", "", CONCAT(" <", users.name, ">")))
      FROM users
      WHERE login LIKE '#{letter}%'
         OR name LIKE '#{letter}%'
         OR name LIKE '% #{letter}%'
      ORDER BY login ASC
    ))
  end
end

class AutoCompleteHerbarium < AutoCompleteByWord
  def rough_matches(letter)
    Herbarium.connection.select_values(%(
      SELECT IF(code = '', name, CONCAT(code, ' - ', name))
      FROM herbaria
      WHERE name LIKE '#{letter}%'
         OR name LIKE '% #{letter}%'
         OR code LIKE '#{letter}%'
      ORDER BY IF(code = '', '~', code) ASC, name ASC
    ))
  end
end

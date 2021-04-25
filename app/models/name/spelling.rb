# frozen_string_literal: true

class Name < AbstractModel
  scope :with_correct_spelling, -> { where(correct_spelling_id: nil) }

  # Is this Name misspelled?
  def is_misspelling?
    !correctly_spelt?
  end

  def correctly_spelt?
    correct_spelling_id.blank?
  end

  # Do some simple queries to try to find alternate spellings of the given
  # (incorrectly-spelled) name.  Returns Array of Name instances.
  def self.suggest_alternate_spellings(str)
    results = []

    # Do some really basic pre-parsing, stripping off author and spuh.
    str = clean_incoming_string(str).
          tr("ë", "e").
          sub(/ sp\.?$/, "").
          tr("_", " ").strip_squeeze.upcase_first
    str = parse_author(str).first # (strip author off)

    # Guess genus first, then species, and so on.
    if str.present?
      words = str.split
      num = words.length
      results = guess_word("", words.first)
      (2..num).each do |i|
        next unless results.any?
        next unless (i & 1).zero?

        prefixes = results.map(&:text_name).uniq
        results = []
        word = i == 2 ? words[i - 1] : "#{words[i - 2]} #{words[i - 1]}"
        prefixes.each { |prefix| results |= guess_word(prefix, word) }
      end
    end

    results
  end

  # Check if the reason that the given name (String) is unrecognized is because
  # it's within a deprecated genus.  Use case: Cladina has been included back
  # within Cladonia, but tons of guides use Cladina anyway, so people like to
  # enter novel names under Cladina, not realizing those names already exist
  # under Cladonia. Returns the parent in question which is deprecated (Name).
  def self.parent_if_parent_deprecated(str)
    result = nil
    names = find_or_create_name_and_parents(str)
    if names.any? && names.last && names.last.deprecated
      for name in names.reverse
        return name if name.id
      end
    end
    result
  end

  # Checks if the deprecated parent has synonyms, and if so, checks if there
  # is a corresponding child under on of the synonymous parents.  Returns an
  # Array of candidates (Name's).
  # str = "Agaricus bogus var. namus"
  def self.names_from_synonymous_genera(str, parent = nil)
    parent ||= parent_if_parent_deprecated(str) # parent = <Agaricus>
    parse = parse_name(str)
    result = []
    if parent && parse
      # child = "bogus var. namus"
      child = parse.real_text_name.sub(/^#{parent.real_text_name}/, "").strip
      # child_pat = "bog% var. nam%"
      child_pat = child.gsub(/(a|um|us)( |$)/, '%\2')
      # synonym = <Lepiota>
      parent.synonyms.each do |synonym|
        # "Lepiota bog% var. nam%"
        conditions = ["text_name like ? AND correct_spelling_id IS NULL",
                      "#{synonym.text_name} #{child_pat}"]
        result += Name.where(conditions).select do |name|
          # name = <Lepiota boga var. nama>
          valid_alternate_genus?(name, synonym.text_name, child_pat)
        end
      end
      # Return only valid candidates if any are valid.
      result.reject!(&:deprecated) if result.any? { |n| !n.deprecated? }
    end
    result
  end

  # The SQL pattern, e.g., "Lepiota test%", is too permissive.  Verify that the
  # results really are of the form /^Lepiota test(a|us|um)$/.
  def self.valid_alternate_genus?(name, parent, child_pat)
    unless (
      match = name.text_name.match(/^#{parent} #{child_pat.gsub('%', '(.*)')}$/)
    )
      return false
    end

    (1..child_pat.count("%")).each do |i|
      return false unless /^(a|us|um)$/.match?(match[i])
    end
    true
  end

  ##############################################################################

  # Guess correct name of partial string.
  # This method should be private.
  # See https://www.pivotaltracker.com/story/show/176098819
  def self.guess_word(prefix, word)
    str = "#{prefix} #{word}"
    results = guess_with_errors(str, 1)
    results = guess_with_errors(str, 2) if results.empty?
    results = guess_with_errors(str, 3) if results.empty?
    results
  end

  # Look up name replacing n letters at a time with a star.
  # This method should be private.
  # See https://www.pivotaltracker.com/story/show/176098819
  def self.guess_with_errors(name, count)
    patterns = []

    # Restrict search to names close in length.
    min_len = Name.connection.quote((name.length - 2).to_s)
    max_len = Name.connection.quote((name.length + 2).to_s)

    # Create a bunch of SQL "like" patterns.
    name = name.gsub(/ \w+\. /, " % ")
    words = name.split
    (0..(words.length - 1)).each do |i|
      word = words[i]
      if word != "%"
        if word.length < count
          patterns << guess_pattern(words, i, "%")
        else
          (0..(word.length - count)).each do |j|
            sub = ""
            sub += word[0..(j - 1)] if j.positive?
            sub += "%"
            sub += word[(j + count)..-1] if j + count < word.length
            patterns << guess_pattern(words, i, sub)
          end
        end
      end
    end

    # Create SQL query out of these patterns.
    conds = patterns.map do |pat|
      "text_name LIKE #{Name.connection.quote(pat)}"
    end.join(" OR ")
    all_conds = "(LENGTH(text_name) BETWEEN #{min_len} AND #{max_len}) " \
                "AND (#{conds}) AND correct_spelling_id IS NULL"
    where(all_conds).limit(10).to_a
  end

  # String words together replacing the one at +index+ with +sub+.
  def self.guess_pattern(words, index, sub) # :nodoc:
    result = []
    (0..(words.length - 1)).each do |j|
      result << (index == j ? sub : words[j])
    end
    result.join(" ")
  end

  private_class_method :guess_pattern
end

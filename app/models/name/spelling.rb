# frozen_string_literal: true

module Name::Spelling
  # When we `include` a module, the way to add class methods is like this:
  def self.included(base)
    base.extend(ClassMethods)
  end

  # Is this Name misspelled?
  def is_misspelling?
    !correctly_spelt?
  end

  def correctly_spelt?
    correct_spelling_id.blank?
  end

  module ClassMethods
    # Do some simple queries to try to find alternate spellings of the given
    # (incorrectly-spelled) name.  Returns Array of Name instances.
    def suggest_alternate_spellings(str)
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
          next unless i.even?

          prefixes = results.map(&:text_name).uniq
          results = []
          word = i == 2 ? words[i - 1] : "#{words[i - 2]} #{words[i - 1]}"
          prefixes.each { |prefix| results |= guess_word(prefix, word) }
        end
      end

      results
    end

    # Check if the reason that given name (String) is unrecognized is because
    # it's within a deprecated genus.  Use case: Cladina has been included back
    # within Cladonia, but tons of guides use Cladina anyway, so people like to
    # enter novel names under Cladina, not realizing those names already exist
    # under Cladonia. Returns the parent in question which is deprecated (Name).
    def parent_if_parent_deprecated(user, str)
      result = nil
      names = find_or_create_name_and_parents(user, str)
      if names.any? && names.last&.deprecated
        names.reverse_each do |name|
          return name if name.id
        end
      end
      result
    end

    # Checks if the deprecated parent has synonyms, and if so, checks if there
    # is a corresponding child under on of the synonymous parents.  Returns an
    # Array of candidates (Name's).
    # str = "Agaricus bogus var. namus"
    def names_from_synonymous_genera(user, str, parent = nil)
      parent ||= parent_if_parent_deprecated(user, str) # parent = <Agaricus>
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
          result += Name.with_correct_spelling.
                    where(Name[:text_name].
                          matches("#{synonym.text_name} #{child_pat}")).
                    select do |name|
            # name = <Lepiota boga var. nama>
            valid_alternate_genus?(name, synonym.text_name, child_pat)
          end
        end
        # Return only valid candidates if any are valid.
        result.reject!(&:deprecated) if result.any? { |n| !n.deprecated? }
      end
      result
    end

    # The SQL pattern, e.g., "Lepiota test%", is too permissive. Verify that the
    # results really are of the form /^Lepiota test(a|us|um)$/.
    def valid_alternate_genus?(name, parent, child_pat)
      unless (match = name.text_name.match(
        /^#{parent} #{child_pat.gsub("%", "(.*)")}$/
      ))
        return false
      end

      (1..child_pat.count("%")).each do |i|
        return false unless /^(a|us|um)$/.match?(match[i])
      end
      true
    end

    ############################################################################

    # Guess correct name of partial string.
    # NOTE: jdc 20250324 (copied from pivotaltracker)
    # guess_word and guess_with_errors should be private.
    # They were intended to be private
    # and had been placed after a call to private.
    # But that call was ineffective, so it was removed.
    # https://docs.rubocop.org/rubocop/1.0/cops_lint.html#lintuselessaccessmodifier
    # Furthermore, they can't be privatized because they are tested directly.
    # So the tests should be fixed first.
    def guess_word(prefix, word)
      str = "#{prefix} #{word}"
      results = guess_with_errors(str, 1)
      results = guess_with_errors(str, 2) if results.empty?
      results = guess_with_errors(str, 3) if results.empty?
      results
    end

    # Look up name replacing n letters at a time with a star.
    def guess_with_errors(name, count)
      patterns = []

      # Restrict search to names close in length.
      min_len = name.length - 2
      max_len = name.length + 2

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
              sub += word[(j + count)..] if j + count < word.length
              patterns << guess_pattern(words, i, sub)
            end
          end
        end
      end

      # Create SQL query out of these patterns.
      Name.with_correct_spelling.
        where(Name[:text_name].length.between(min_len..max_len)).
        where(Name[:text_name].matches_any(patterns)).limit(10).to_a
    end

    private

    # String words together replacing the one at +index+ with +sub+.
    def guess_pattern(words, index, sub) # :nodoc:
      result = (0..(words.length - 1)).map do |j|
        (index == j ? sub : words[j])
      end
      result.join(" ")
    end

    public

    # This catches cases where correct_spelling_id = id and just clears it.
    # Not sure why this would ever happen, but empirically there are presently
    # three cases of it in the database.  Presumably something to do with
    # name merges?  Whatever.  This fixes it and will run nightly. -JPH 20210812
    def fix_self_referential_misspellings(dry_run: false)
      msgs = Name.with_self_referential_misspelling.
             select(:id, :text_name, :author).map do |name|
               "Name ##{name.id} #{name.text_name} #{name.author} " \
                 "was a misspelling of itself."
             end
      unless dry_run
        Name.with_self_referential_misspelling.
          update_all(correct_spelling_id: nil)
      end
      msgs
    end
  end
end

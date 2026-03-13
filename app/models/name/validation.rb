# frozen_string_literal: true

module Name::Validation
  # When we `include` a module, the way to add class methods is like this:
  def self.included(base)
    base.extend(ClassMethods)
  end

  module ClassMethods
    # :string field size limits in characters, based on this algorithm:
    # Theoretical max differences between (text_name + author) and the field
    #   search_name: 4
    #     Adding a " sp." at the end is the worst case.
    #   sort_name:   21
    #     It adds " {N" and " !" (5 chars) in front of subgenus and the epithet
    #     that goes with it. There can be up to 4 infrageneric ranks (subgenus,
    #     section, subsection, stirps, plus the space between name and author.
    #     That adds up to 5*4 + 1 = 21.
    #   display_name: 41
    #     Adds the space between name and author; "**__" and "__**" (8 chars)
    #     around every epithet, grouping genus and species. Infrageneric ranks
    #     win, making as many as 5 separate bold epithets or epithet pairs.
    #     That adds up to 8*5 + 1 = 41.

    # Numbers are hard-coded (rather than calculated) to make it easier to copy
    # them to migrations.

    # An arbitrary number intended to be large enough for all Names
    def text_name_limit
      100
    end

    # An arbitary number intended to be large enough to include all abbreviated
    # authors. There are now some Names with > text_name_limit worth of authors.
    # Rather than increase this limit, we will suggest that multiple authors be
    # listed as "first_author & al." per ICN Recommendation 46C.2.
    def author_limit
      100
    end

    # text_name_limit + author_limit + 4
    def search_name_limit
      204
    end

    # text_name_limit + author_limit + 21
    def sort_name_limit
      221
    end

    # text_name_limit + author_limit + 41
    def display_name_limit
      241
    end
  end

  ##############################################################################

  private

  def user_presence
    errors.add(:user, :validate_name_user_missing.t) \
      if !user_id && !User.current
  end

  def text_name_length
    return if text_name.to_s.size <= Name.text_name_limit

    errors.add(
      :text_name,
      "#{:validate_name_text_name_too_long.t} #{:MAXIMUM.t}: " \
      "#{Name.text_name_limit}"
    )
  end

  def author_length
    return if author.to_s.size <= Name.author_limit

    errors.add(
      :author,
      "#{:validate_name_author_too_long.t} #{:MAXIMUM.t}: " \
      "#{Name.author_limit}. #{:validate_name_use_first_author.t}."
    )
  end

  def normalize_author_characters!
    author&.unicode_normalize!(:nfc)
  end

  def search_name_indistinct
    hnyms = homonyms
    return if hnyms.none?

    cleaned_search_name = cleaned_search_name(search_name)
    hnyms.each do |homonym|
      cleaned_homonym_search_name = cleaned_search_name(homonym.search_name)
      next unless cleaned_search_name == cleaned_homonym_search_name

      errors.add(
        :search_name,
        "#{:validate_name_equivalent_exists.t}: " \
        "#{homonym.display_name.t} (#{homonym.id})"
      )
    end
  end

  def cleaned_search_name(string)
    I18n.transliterate(string). # Make it ASCII
      downcase. # ignore case differences
      gsub(/[^a-z0-9 ]/, "") # Remove non-alphanumerics (like punctuation)
  end

  def citation_start
    # Should not start with punctuation other than:
    # quotes, period, close paren, close bracket
    # question mark (used for Textile italics)
    # underscore (previously used for Textile italics)
    return unless (
      start = %r{\A[\s!#%&)*+,\-./:;<=>@\[\]^{|}~]+}.match(citation)
    )

    errors.add(:base,
               :name_error_field_start.t(field: :CITATION.t, start: start))
  end

  # prevent assigning ICN registration identifier to unregistrable Name
  def icn_id_registrable
    return if icn_id.blank? || registrable?

    errors.add(:base, :name_error_unregistrable.t(
                        rank: rank.to_s, name: user_real_search_name(nil)
                      ))
  end

  # Require icn_id to be unique
  # Use validation method (rather than :validates_uniqueness_of)
  # to get correct error message.
  def icn_id_unique
    return if icn_id.nil?
    return if (conflicting_name = other_names_with_same_icn_id.first).blank?

    errors.add(:base, :name_error_icn_id_in_use.t(
                        number: icn_id,
                        name: conflicting_name.user_real_search_name(nil)
                      ))
  end

  def other_names_with_same_icn_id
    Name.where(icn_id: icn_id).where.not(id: id)
  end
end

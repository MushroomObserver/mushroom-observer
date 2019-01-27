class Name < AbstractModel
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
  def self.text_name_limit
    100
  end

  # An arbitary number intended to be large enough to include all abbreviated
  # authors. There are now some Names with > text_name_limit worth of authors.
  # Rather than increase this limit, we will suggest that multiple authors be
  # listed as "first_author & al." per ICN Recommendation 46C.2.
  def self.author_limit
    100
  end

  # text_name_limit + author_limit + 4
  def self.search_name_limit
    204
  end

  # text_name_limit + author_limit + 21
  def self.sort_name_limit
    221
  end

  # text_name_limit + author_limit + 41
  def self.display_name_limit
    241
  end

  ##############################################################################

  private

  validate :check_user, :check_text_name, :check_author

  # :stopdoc:
  def check_author
    return if author.to_s.size <= Name.author_limit

    errors.add(
      :author,
      "#{:validate_name_author_too_long.t} #{:MAXIMUM.t}: "\
      "#{Name.author_limit}. #{:validate_name_use_first_author.t}."
    )
  end

  def check_text_name
    return if text_name.to_s.size <= Name.text_name_limit

    errors.add(
      :text_name,
      "#{:validate_name_text_name_too_long.t} #{:MAXIMUM.t}: "\
      "#{Name.text_name_limit}"
    )
  end

  def check_user
    errors.add(:user, :validate_name_user_missing.t) if !user && !User.current
  end
end

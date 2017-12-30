class Name < AbstractModel
  # Returns "Deprecated" or "Valid" in the local language.
  def status
    deprecated ? :DEPRECATED.l : :ACCEPTED.l
  end

  # Same as synonyms, but returns ids.
  def synonym_ids
    @synonym_ids ||= begin
      if @synonyms
        @synonyms.map(&:id)
      elsif synonym_id
        Name.connection.select_values(%(
          SELECT id FROM names WHERE synonym_id = #{synonym_id}
        )).map(&:to_i)
      else
        [id]
      end
    end
  end

  # Returns an Array of all synonym Name's, including itself and misspellings.
  def synonyms
    @synonyms ||= begin
      if @synonym_ids
        # Slightly faster than below since id is primary index.
        Name.where(id: @synonym_ids).to_a
      elsif synonym_id
        # This is apparently faster than synonym.names.
        Name.where(synonym_id: synonym_id).to_a
      else
        [self]
      end
    end
  end

  # Returns an Array of all _approved_ Synonym Name's, potentially including
  # itself.
  def approved_synonyms
    synonyms.reject(&:deprecated)
  end

  # Returns an Array of approved Synonym Name's and an Array of deprecated
  # Synonym Name's, including misspellings, but _NOT_ including itself.
  #
  #   approved_synonyms, deprecated_synonyms = name.sort_synonyms
  #
  def sort_synonyms
    all = synonyms - [self]
    accepted_synonyms   = all.reject(&:deprecated)
    deprecated_synonyms = all.select(&:deprecated)
    [accepted_synonyms, deprecated_synonyms]
  end

  # Same as +other_authors+, but returns ids.
  def other_author_ids
    @other_author_ids ||= begin
      if @other_authors
        @other_authors.map(&:id)
      else
        Name.connection.select_values(%(
          SELECT id FROM names WHERE text_name = '#{text_name}'
        )).map(&:to_i)
      end
    end
  end

  # Returns an Array of Name's, including itself, which differ only in author.
  def other_authors
    @other_authors ||= begin
      if @other_author_ids
        # Slightly faster since id is primary index.
        Name.where(id: @other_author_ids).to_a
      else
        Name.where(text_name: text_name).to_a
      end
    end
  end

  # Removes this Name from its old Synonym.  It destroys the Synonym if there's
  # only one Name left in it afterword.  Returns nothing.  Any changes are
  # saved.
  #
  #   # If we have a group of three synonyms, say ids 1, 2 and 3:
  #   puts "before:   " + name.synonyms.map(&:id).join(', ')
  #   name1, name2, name3 = name.synonyms
  #   name1.clear_synonym
  #   puts "after 1:  " + name1.synonyms.map(&:id).join(', ')
  #   puts "after 2:  " + name2.synonyms.map(&:id).join(', ')
  #   puts "after 3:  " + name3.synonyms.map(&:id).join(', ')
  #
  #   # Produces:
  #   before:   1, 2, 3
  #   after 1:  1
  #   after 2:  2, 3
  #   after 3:  2, 3
  #
  def clear_synonym
    return unless synonym_id
    names = synonyms

    # Get rid of the synonym if only one going to be left in it.
    if names.length <= 2
      synonym.destroy
      names.each do |n|
        n.synonym_id = nil
        # n.accepted_name = n
        n.save
      end

    # Otherwise, just detach this name.
    else
      self.synonym_id = nil
      save
    end

    # This has to apply to names that are misspellings of this name, too.
    Name.where(correct_spelling: self).each do |n|
      n.update_attribute!(correct_spelling: nil)
    end
  end

  # Makes two Name's synonymous.  If either Name already has a Synonym, it will
  # merge the Synonym(s) into a single Synonym.  Returns nothing.  Any changes
  # are saved.
  #
  #   puts "before 1:  " + name1.synonyms.map(&:id).join(', ')
  #   puts "before 2:  " + name2.synonyms.map(&:id).join(', ')
  #   name1.merge_synonyms(name2)
  #   puts "after 1:   " + name1.synonyms.map(&:id).join(', ')
  #   puts "after 2:   " + name2.synonyms.map(&:id).join(', ')
  #
  #   # Produces:
  #   before 1:   1, 3
  #   before 2:   2
  #   after 1:  1, 2, 3
  #   after 2:  1, 2, 3
  #
  def merge_synonyms(name)
    # Other name has no synonyms, just transfer it over.
    if !name.synonym_id
      transfer_synonym(name)

    # *This* name has no synonyms, transfer us over to it.
    elsif !synonym_id
      name.transfer_synonym(self)

    # Both have synonyms -- merge them.
    # (Make sure they aren't already synonymized!)
    elsif synonym_id != name.synonym_id
      name.synonyms.each { |n| transfer_synonym(n) }
    end

    # synonym.choose_accepted_name
  end

  # Add Name to this Name's Synonym, but don't transfer that Name's synonyms.
  # Delete the other Name's old Synonym if there aren't any Name's in it
  # anymore.  Everything is saved.  (*NOTE*: Creates a new Synonym for this
  # Name if it doesn't already have one.)
  #
  #   correct_name.transfer_synonym(incorrect_name)
  #
  def transfer_synonym(name)
    # Make sure this name is attached to a synonym, creating one if necessary.
    unless synonym_id
      self.synonym = Synonym.create
      save
    end

    # Only transfer it over if it's not already a synonym!
    return unless synonym_id != name.synonym_id

    # Destroy old synonym if only one name left in it.
    name.synonym.destroy if name.synonym && (name.synonyms.length <= 2)

    # Attach name to our synonym.
    name.synonym_id = synonym_id
    name.save
  end

  def observation_count
    observations.length
  end

  # Returns either self or name,
  # whichever has more observations or was last used.
  def more_popular(name)
    result = self
    unless name.deprecated
      if deprecated
        result = name
      elsif observation_count < name.observation_count
        result = name
      elsif time_of_last_naming < name.time_of_last_naming
        result = name
      end
    end
    result
  end

  # (if no namings, returns created_at)
  def time_of_last_naming
    @time_of_last_naming ||= begin
      last_use = Name.connection.select_value("SELECT MAX(created_at) FROM namings WHERE name_id = #{id}")
      last_use || created_at
    end
  end
end

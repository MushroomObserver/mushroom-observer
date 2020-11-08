# frozen_string_literal: true

# Synonyms of Names
class Name < AbstractModel
  # Returns "Deprecated" or "Valid" in the local language.
  def status
    deprecated ? :DEPRECATED.l : :ACCEPTED.l
  end

  # Same as synonyms, but returns ids.
  def synonym_ids
    synonym ? synonym.name_ids.to_a : [id]
  end

  # Same as synonym_ids, but excludes self.id
  def other_synonym_ids
    synonym_ids.drop(1)
  end

  # Returns an Array of all synonym Name's including itself at front of list.
  # (This looks screwy, but I think it is the safest way to handle it.
  # Note that synonym.names does include self, but it's a different instance.
  # So if you make changes to the self that synonym.names returns, it will
  # not show up in self itself.  So this ensures that self itself will be
  # included at the beginning of the list of synonyms.)
  def synonyms
    synonym ? [self] + (synonym.names.to_a - [self]) : [self]
  end

  # Returns an Array of all _approved_ Synonym Name's, potentially including
  # itself.
  def approved_synonyms
    synonyms.reject(&:deprecated)
  end

  # Array of approved synonyms, excluding self
  def other_approved_synonyms
    approved_synonyms - [self]
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
        Name.pluck(:id).where(text_name: text_name).map(&:to_i)
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
    return unless synonym

    names = synonyms

    # Get rid of the synonym if only one's going to be left in it.
    if names.count <= 2
      synonym&.destroy
      names.each do |n|
        n.synonym = nil
        n.save
      end

    # Otherwise, just detach this name.
    else
      self.synonym = nil
      save
    end

    # This has to apply to names that are misspellings of this name, too.
    Name.where(correct_spelling: self).find_each do |n|
      n.correct_spelling = nil
      n.save
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
  # rubocop:disable Style/RedundantSelf
  # I think these methods read much better with self explicitly included. -JPH
  # rubocop:disable Metrics/AbcSize
  # This is the best I can do. I think splitting it up will make it worse. -JPH
  def merge_synonyms(name)
    if !self.synonym && !name.synonym
      self.synonym = name.synonym = Synonym.create
      self.save
      name.save

    elsif !name.synonym
      name.synonym = self.synonym
      name.save

    elsif !self.synonym
      self.synonym = name.synonym
      self.save

    elsif self.synonym != name.synonym
      names = name.synonyms
      name.synonym&.destroy
      names.each do |n|
        n.synonym = self.synonym
        n.save
      end
    end
  end
  # rubocop:enable Metrics/AbcSize

  # Add Name to this Name's Synonym, but don't transfer that Name's synonyms.
  # Delete the other Name's old Synonym if there aren't any Name's in it
  # anymore.  Everything is saved.  (*NOTE*: Creates a new Synonym for this
  # Name if it doesn't already have one.)
  #
  #   correct_name.transfer_synonym(incorrect_name)
  #
  def transfer_synonym(name)
    return if self == name
    return if self.synonym && self.synonym == name.synonym

    name.clear_synonym
    self.merge_synonyms(name)
  end
  # rubocop:enable Style/RedundantSelf

  def observation_count
    observations.count
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
      last_use = Name.connection.select_value(
        "SELECT MAX(created_at) FROM namings WHERE name_id = #{id}"
      )
      last_use || created_at
    end
  end

  # "Best" preferred synonym of a deprecated name.
  def best_preferred_synonym
    most_recently_updated(preferred_synonyms_with_most_observations)
  end

  ##############################################################################

  private

  # array of synonyms with the most observations, sorted by observation_count
  def preferred_synonyms_with_most_observations
    betters = preferreds_by_observation_count_descending
    max_observations = betters.first&.observation_count
    betters.select { |name| name.observation_count == max_observations }
  end

  def preferreds_by_observation_count_descending
    other_approved_synonyms.sort_by { |name| -name.observation_count }
  end

  def most_recently_updated(names)
    names.max_by(&:updated_at)
  end
end

# frozen_string_literal: true

module Name::Change
  # Changes the name, and creates parents as necessary.  Throws a RuntimeError
  # with error message if unsuccessful in any way.  Returns nothing. *UNSAVED*!!
  #
  # *NOTE*: It does not save the changes to itself, but if it has to create or
  # update any parents (and caller has requested it), _those_ do get saved.
  #
  def change_text_name(user, in_text_name, in_author, in_rank,
                       save_parents = false)
    in_str = Name.clean_incoming_string("#{in_text_name} #{in_author}")
    parse = Name.parse_name(in_str, rank: in_rank, deprecated: deprecated)
    if !parse || parse.rank != in_rank
      raise(:runtime_invalid_for_rank.t(rank: :"rank_#{in_rank.to_s.downcase}",
                                        name: in_str))
    end
    if parse.parent_name &&
       !Name.find_by(text_name: parse.parent_name)
      parents = Name.find_or_create_name_and_parents(user, parse.parent_name)
      if parents.last.nil?
        raise(:runtime_unable_to_create_name.t(name: parse.parent_name))
      end

      parents.each { |n| n.save if n&.new_record? } if save_parents
    end
    self.attributes = parse.params
  end

  # Changes author.  Updates formatted names, as well.  *UNSAVED*!!
  #
  #   name.change_author('New Author')
  #   name.save
  #
  def change_author(new_author)
    return if rank == "Group"

    new_author2 = new_author.blank? ? "" : " #{new_author}"
    self.author = new_author.to_s
    self.search_name  = text_name + new_author2
    self.sort_name    = Name.format_sort_name(text_name, new_author)
    self.display_name = Name.format_autonym(text_name, new_author, rank,
                                            deprecated)
  end

  # Changes deprecated status.  Updates formatted names, as well. *UNSAVED*!!
  #
  #   name.change_deprecated(true)
  #   name.save
  #
  def change_deprecated(deprecated)
    # remove existing boldness
    name = self[:display_name].gsub(/\*\*([^*]+)\*\*/, '\1')
    unless deprecated
      # add new boldness
      name.gsub!(/(__[^_]+__)/, '**\1**')
      self.correct_spelling = nil
    end
    self.display_name = name
    self.deprecated = deprecated
    # synonym.choose_accepted_name if synonym
  end

  # Mark this name as "misspelled", make sure it is deprecated, record what the
  # correct spelling should be, make sure it is NOT deprecated, and make sure
  # it is a synonym of this name.  Saves any changes it needs to make to the
  # correct spelling, but only saves the changes to this name if you ask it to.
  def mark_misspelled(user, target_name, save = false)
    return if deprecated && misspelling && correct_spelling == target_name

    self.misspelling = true
    self.correct_spelling = target_name
    change_deprecated(true)
    merge_synonyms(target_name)
    target_name.clear_misspelled(user, :save) if target_name.is_misspelling?
    save_with_log(user, :log_name_deprecated, other: target_name.display_name) \
      if save
    change_misspelled_consensus_names
  end

  # Mark this name as "not misspelled", and saves the changes if you ask it to.
  def clear_misspelled(user, save = false)
    return unless misspelling || correct_spelling

    was = correct_spelling.user_display_name(user)
    self.misspelling = false
    self.correct_spelling = nil
    save_with_log(user, :log_name_unmisspelled, other: was) if save
  end

  # Super quick and low-level update to make sure no observation names are
  # misspellings.
  def change_misspelled_consensus_names
    Observation.where(name_id: id).update_all(name_id: correct_spelling_id)
  end
end

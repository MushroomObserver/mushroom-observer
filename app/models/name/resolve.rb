# frozen_string_literal: true

class Name < AbstractModel
  # Resolves the name using these heuristics:
  #   First time through:
  #     Only 'what' will be filled in.
  #     Prompts the user if not found.
  #     Gives user a list of options if matches more than one. ('names')
  #     Gives user a list of options if deprecated. ('valid_names')
  #   Second time through:
  #     'what' is a new string if user typed new name, else same as old 'what'
  #     'approved_name' is old 'what'
  #     'chosen_name' hash on name.id: radio buttons
  #     Uses the name chosen from the radio buttons first.
  #     If 'what' has changed, then go back to "First time through" above.
  #     Else 'what' has been approved, create it if necessary.
  #
  # INPUTS:
  #   what            params[:name][:name]            Text field.
  #   approved_name   params[:approved_name]          Last name user entered.
  #   chosen_name     params[:chosen_name][:name_id]  Name id from radio boxes.
  #   (User.current -- might be used by one or more things)
  #
  # RETURNS:
  #   success       true: okay to use name; false: user needs to approve name.
  #   name          Name object if it resolved without reservations.
  #   names         List of choices if name matched multiple objects.
  #   valid_names   List of choices if name is deprecated.
  #
  def self.resolve_name(what, approved_name, chosen_name)
    success = true
    name = nil
    names = nil
    valid_names = nil
    parent_deprecated = nil
    suggest_corrections = false

    what2 = what.to_s.tr("_", " ").strip_squeeze
    approved_name2 = approved_name.to_s.tr("_", " ").strip_squeeze

    unless what2.blank? || names_for_unknown.member?(what2.downcase)
      success = false

      ignore_approved_name = false
      # Has user chosen among multiple matching names or among
      # multiple approved names?
      if chosen_name.blank?
        what2 = fix_capitalized_species_epithet(what2)

        # Look up name: can return zero (unrecognized), one
        # (unambiguous match), or many (multiple authors match).
        names = find_names_filling_in_authors(what2)
      else
        names = [find(chosen_name)]
        # This tells it to check if this name is deprecated below EVEN
        # IF the user didn't change the what field.  This will solve
        # the problem of multiple matching deprecated names discussed
        # below.
        ignore_approved_name = true
      end

      # Create temporary name object for it.  (This will not save anything
      # EXCEPT in the case of user supplying author for existing name that
      # has no author.)
      if names.empty? &&
         (name = create_needed_names(approved_name2, what2))
        names << name
      end

      # No matches -- suggest some correct names to make Debbie happy.
      if names.empty?
        if (parent = parent_if_parent_deprecated(what2))
          valid_names = names_from_synonymous_genera(what2, parent)
          parent_deprecated = parent
        else
          valid_names = suggest_alternate_spellings(what2)
          suggest_corrections = true
        end

      # Only one match (or we just created an approved new name).
      elsif names.length == 1
        target_name = names.first
        # Single matching name.  Check if it's deprecated.
        if target_name.deprecated &&
           (ignore_approved_name || (approved_name != what))
          # User has not explicitly approved the deprecated name: get list of
          # valid synonyms.  Will display them for user to choose among.
          valid_names = target_name.approved_synonyms
        else
          # User has selected an unambiguous, accepted name... or they have
          # chosen or approved of their choice.  Either way, go with it.
          name = target_name
          # Fill in author, just in case user has chosen between two authors.
          # If the form fails for some other reason and we don't do this, it
          # will ask the user to choose between the authors *again* later.
          what = name.real_search_name
          # (This is the only way to get out of here with success.)
          success = true
        end

      # Multiple matches.
      elsif names.length > 1
        if names.reject(&:deprecated).empty?
          # Multiple matches, all of which are deprecated.  Check if
          # they all have the same set of approved names.  Pain in the
          # butt, but otherwise can get stuck choosing between
          # Helvella infula Fr. and H. infula Schaeff. without anyone
          # mentioning that both are deprecated by Gyromitra infula.
          valid_set = Set.new
          names.each do |n|
            valid_set.merge(n.approved_synonyms)
          end
          valid_names = valid_set.sort_by(&:sort_name)
        end
      end
    end

    [success, what, name, names, valid_names, parent_deprecated,
     suggest_corrections]
  end

  def self.create_needed_names(input_what, output_what = nil)
    names = []
    if output_what.nil? || input_what == output_what
      names = find_or_create_name_and_parents(input_what)
      if names.last
        names.each do |n|
          next unless n&.new_record?

          n.inherit_stuff
          n.save_with_log(:log_updated_by)
        end
      end
    end
    names.last
  end

  def self.save_names(names, deprecate)
    log = nil
    unless deprecate.nil?
      log = if deprecate
              :log_deprecated_by
            else
              :log_approved_by
            end
    end
    names.each do |n|
      next unless n&.new_record?

      n.change_deprecated(deprecate) if deprecate
      n.inherit_stuff
      n.save_with_log(log)
    end
  end

  def save_with_log(log = nil, args = {})
    return false unless changed?

    log ||= :log_name_updated
    args = { touch: altered? }.merge(args)
    log(log, args)
    save
  end

  # A common mistake is capitalizing the species epithet. If the second word
  # is capitalized, and the name isn't recognized if the second word is
  # interpreted as an author, and it *is* recognized if changed to lowercase,
  # this method changes the second word to lowercase.  Returns fixed string.
  def self.fix_capitalized_species_epithet(str)

    # Is second word capitalized?
    return str unless str.match?(/^\S+ [A-Z]/)

    # Trust it if there is actually a name with that author present.
    return str if Name.find_by_search_name(str).present?

    # Try converting second word to lowercase.
    str2 = str.sub(/ [A-Z]/) { |match| match.downcase }

    # Return corrected name if that name exists, else keep original name.
    if Name.where("search_name = ? OR text_name = ?", str2, str2).present?
      return str2
    else
      return str
    end
  end
end

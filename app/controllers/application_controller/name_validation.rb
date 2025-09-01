# frozen_string_literal: true

#  ==== Name validation
#  construct_approved_names:: Creates a list of names if they've been approved.
#  construct_approved_name::  (helper)
#
module ApplicationController::NameValidation
  ##############################################################################
  #
  #  :section: Name validation
  #
  ##############################################################################

  # Goes through list of names entered by user and creates (and saves) any that
  # are not in the database (but only if user has approved them).
  #
  # Used by: change_synonyms, create/edit_species_list
  #
  # Inputs:
  #
  #   name_list         string, delimted by newlines (see below for syntax)
  #   approved_names    array of real_search_names (or string delimited by "/")
  #   deprecate?        are any created names to be deprecated?
  #
  # Syntax: (NameParse class does the actual parsing)
  #
  #   Xxx yyy
  #   Xxx yyy var. zzz
  #   Xxx yyy Author
  #   Xxx yyy sensu Blah
  #   Valid name Author = Deprecated name Author
  #   blah blah [comment]
  #
  def construct_approved_names(name_list, approved_names, deprecate: false)
    return unless approved_names

    if approved_names.is_a?(String)
      approved_names = approved_names.split(/\r?\n/)
    end
    name_list.split("\n").each do |ns|
      next if ns.blank?

      name_parse = NameParse.new(ns)
      construct_approved_name(name_parse, approved_names, deprecate)
    end
  end

  # Processes a single line from the list above.
  # Used only by construct_approved_names().
  def construct_approved_name(name_parse, approved_names, deprecate)
    # Don't do anything if the given names are not approved
    if approved_names.member?(name_parse.name)
      # Build just the given names (not synonyms)
      construct_given_name(name_parse, deprecate)
    end

    # Do the same thing for synonym (found the Approved = Synonym syntax).
    return unless name_parse.has_synonym? &&
                  approved_names.member?(name_parse.synonym)

    construct_synonyms(name_parse)
  end

  def construct_given_name(name_parse, deprecate)
    # Create name object for this name (and any parents, such as genus).
    names = Name.find_or_create_name_and_parents(@user, name_parse.search_name)

    # if above parse was successful
    if (name = names.last)
      name.rank = name_parse.rank if name_parse.rank
      save_approved_given_names(names, deprecate)

    # Parse must have failed.
    else
      flash_error(:runtime_no_create_name.t(type: :name,
                                            value: name_parse.name))
    end
  end

  def save_approved_given_names(names, deprecate2)
    Name.save_names(@user, names, deprecate2)
    names.each { |n| flash_object_errors(n) }
  end

  def construct_synonyms(name_parse)
    synonyms = create_synonym(name_parse)

    # Parse was successful
    if (synonym = synonyms.last)
      synonym.rank = name_parse.synonym_rank if name_parse.synonym_rank
      save_synonyms(synonym, synonyms)

    # Parse must have failed.
    else
      flash_error(:runtime_no_create_name.t(type: :name,
                                            value: name_parse.synonym))
    end
  end

  def create_synonym(name_parse)
    Name.find_or_create_name_and_parents(@user, name_parse.synonym_search_name)
  end

  # Deprecate and save.
  def save_synonyms(synonym, synonyms)
    synonym.change_deprecated(true)
    synonym.save_with_log(@user, :log_deprecated_by, touch: true)
    Name.save_names(@user, synonyms[0..-2], nil) # Don't change higher taxa
  end
end

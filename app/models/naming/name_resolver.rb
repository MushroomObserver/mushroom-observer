# frozen_string_literal: true

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
#   what           params[:naming][:name]          Text field.
#   approved_name  params[:approved_name]          Last name user entered.
#   chosen_name    params[:chosen_name][:name_id]  Name id from radio boxes.
#   (User.current -- might be used by one or more things)
#
# RETURNS:
#   success       true: okay to use name; false: user needs to approve name.
#   name          Name object if it resolved without reservations.
#
#   Used by form_name_feedback if name not resolved:
#   names         List of choices if name matched multiple objects.
#   valid_names   List of choices if name is deprecated.
#   parent_deprecated   Boolean
#   suggest_corrections Boolean
#
class Naming
  class NameResolver
    attr_reader :success, :name, :names, :valid_names, :parent_deprecated,
                :suggest_corrections

    def initialize(given_name, approved_name, chosen_name)
      @success = true
      @given_name = given_name
      @name = nil
      @names = nil
      @valid_names = nil
      @parent_deprecated = nil
      @suggest_corrections = false

      resolve(given_name, approved_name, chosen_name)
    end

    # rubocop:disable Metrics/MethodLength
    def resolve(given_name, approved_name, chosen_name)
      corrected = given_name.to_s.tr("_", " ").strip_squeeze
      approved_name2 = approved_name.to_s.tr("_", " ").strip_squeeze
      if corrected.blank? || Name.names_for_unknown.member?(corrected.downcase)
        return
      end

      @success = false

      ignore_approved_name = false
      # Has user chosen among multiple matching names or among
      # multiple approved names?
      if chosen_name.blank?
        corrected = Name.fix_capitalized_species_epithet(corrected)

        # Look up name: can return zero (unrecognized), one
        # (unambiguous match), or many (multiple authors match).
        @names = Name.find_names_filling_in_authors(corrected)
      else
        @names = [Name.find(chosen_name)]
        # This tells it to check if this name is deprecated below EVEN
        # IF the user didn't change the what field.  This will solve
        # the problem of multiple matching deprecated names discussed
        # below.
        ignore_approved_name = true
      end

      # Create temporary name object for it.  (This will not save anything
      # EXCEPT in the case of user supplying author for existing name that
      # has no author.)
      if @names.empty? &&
         (@name = Name.create_needed_names(approved_name2, corrected))
        @names << name
      end

      # No matches -- suggest some correct names to make Debbie happy.
      if @names.empty?
        if (parent = Name.parent_if_parent_deprecated(corrected))
          @valid_names = Name.names_from_synonymous_genera(corrected, parent)
          @parent_deprecated = parent
        else
          @valid_names = Name.suggest_alternate_spellings(corrected)
          @suggest_corrections = true
        end

      # Only one match (or we just created an approved new name).
      elsif @names.length == 1
        target_name = names.first
        # Single matching name.  Check if it's deprecated.
        if target_name.deprecated &&
           (ignore_approved_name || (approved_name != given_name))
          # User has not explicitly approved the deprecated name: get list of
          # valid synonyms.  Will display them for user to choose among.
          @valid_names = target_name.approved_synonyms
        else
          # User has selected an unambiguous, accepted name... or they have
          # chosen or approved of their choice.  Either way, go with it.
          @name = target_name
          # Fill in author, just in case user has chosen between two authors.
          # If the form fails for some other reason and we don't do this, it
          # will ask the user to choose between the authors *again* later.
          @given_name = name.real_search_name
          # (This is the only way to get out of here with success.)
          @success = true
        end

      # Multiple matches.
      elsif @names.length > 1
        if @names.reject(&:deprecated).empty?
          # Multiple matches, all of which are deprecated.  Check if
          # they all have the same set of approved names.  Pain in the
          # butt, but otherwise can get stuck choosing between
          # Helvella infula Fr. and H. infula Schaeff. without anyone
          # mentioning that both are deprecated by Gyromitra infula.
          valid_set = Set.new
          @names.each do |n|
            valid_set.merge(n.approved_synonyms)
          end
          @valid_names = valid_set.sort_by(&:sort_name)
        end
      end
    end
    # rubocop:enable Metrics/MethodLength

    # Convenience method returning a hash for mass ivar assignment
    def results
      { success: @success,
        what: @given_name,
        name: @name,
        names: @names,
        valid_names: @valid_names,
        parent_deprecated: @parent_deprecated,
        suggest_corrections: @suggest_corrections }
    end
  end
end

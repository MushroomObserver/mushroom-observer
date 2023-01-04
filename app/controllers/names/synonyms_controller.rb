# frozen_string_literal: true

#  == SYNONYMS
#  change_synonyms::             Change list of synonyms for a name.
#  deprecate_name::              Deprecate name in favor of another.
#  approve_name::                Flag given name as "accepted"
#                                (others could be, too).
#  ==== Helpers
#  deprecate_synonym::           (used by change_synonyms)
#  check_for_new_synonym::       (used by change_synonyms)
#
#  dump_sorter::                 Error diagnostics for change_synonyms.

module Names
  class SynonymsController < ApplicationController
    ############################################################################
    #
    #  :section: Synonymy
    #
    ############################################################################

    # Form accessible from show_name that lets a user review all the synonyms
    # of a name, removing others, writing in new, etc.
    def change_synonyms
      pass_query_params
      @name = find_or_goto_index(Name, params[:id].to_s)
      return unless @name
      return if abort_if_name_locked!(@name)

      @list_members     = nil
      @new_names        = nil
      @synonym_name_ids = []
      @synonym_names    = []
      @deprecate_all    = true

      post_change_synonyms if request.method == "POST"
    end

    def post_change_synonyms
      list = params[:synonym][:members].strip_squeeze
      @deprecate_all = (params[:deprecate][:all] == "1")

      # Create any new names that have been approved.
      construct_approved_names(list, params[:approved_names], @deprecate_all)

      # Parse the write-in list of names.
      sorter = NameSorter.new
      sorter.sort_names(list)
      sorter.append_approved_synonyms(params[:approved_synonyms])

      # Are any names unrecognized (only unapproved names will still be
      # unrecognized at this point) or ambiguous?
      if !sorter.only_single_names
        dump_sorter(sorter)
      # Has the user NOT had a chance to choose from among the synonyms of any
      # names they've written in?
      elsif !sorter.only_approved_synonyms
        flash_notice(:name_change_synonyms_confirm.t)
      else
        # Go through list of all synonyms for this name and written-in names.
        # Exclude any names that have un-checked check-boxes: newly written-in
        # names will not have a check-box yet, names written-in in previous
        # attempt to submit this form will have checkboxes and therefore must
        # be checked to proceed -- the default initial state.
        proposed_synonyms = params[:proposed_synonyms] || {}
        sorter.all_synonyms.each do |n|
          # It is possible these names may be changed by transfer_synonym,
          # but these *instances* will not reflect those changes, so reload.
          if proposed_synonyms[n.id.to_s] != "0"
            @name.transfer_synonym(n.reload)
          end
        end

        # De-synonymize any old synonyms in the "existing synonyms" list that
        # have been unchecked.  This creates a new synonym to connect them if
        # there are multiple unchecked names -- that is, it splits this
        # synonym into two synonyms, with checked names staying in this one,
        # and unchecked names moving to the new one.
        split_off_desynonymized_names(@name, params[:existing_synonyms] || {})

        # Deprecate everything if that check-box has been marked.
        success = true
        if @deprecate_all
          sorter.all_names.each do |n|
            unless deprecate_synonym(n)
              # Already flashed error message.
              success = false
            end
          end
        end

        if success
          redirect_with_query(action: "show_name", id: @name.id)
        else
          flash_object_errors(@name)
          flash_object_errors(@name.synonym)
        end
      end

      @list_members     = sorter.all_line_strs.join("\r\n")
      @new_names        = sorter.new_name_strs.uniq
      @synonym_name_ids = sorter.all_synonyms.map(&:id)
      @synonym_names    = @synonym_name_ids.filter_map do |id|
        Name.safe_find(id)
      end
    end

    # Form accessible from show_name that lets the user deprecate a name
    # in favor of another name.
    def deprecate_name
      pass_query_params

      # These parameters aren't always provided.
      params[:proposed]    ||= {}
      params[:comment]     ||= {}
      params[:chosen_name] ||= {}
      params[:is]          ||= {}

      @name = find_or_goto_index(Name, params[:id].to_s)
      return unless @name
      return if abort_if_name_locked!(@name)

      @what             = params[:proposed][:name].to_s.strip_squeeze
      @comment          = params[:comment][:comment].to_s.strip_squeeze
      @list_members     = nil
      @new_names        = []
      @synonym_name_ids = []
      @synonym_names    = []
      @deprecate_all    = "1"
      @names            = []
      @misspelling      = (params[:is][:misspelling] == "1")

      post_deprecate_name if request.method == "POST"
    end

    def post_deprecate_name
      if @what.blank?
        flash_error(:runtime_name_deprecate_must_choose.t)
        return
      end

      # Find the chosen preferred name.
      @names = if params[:chosen_name][:name_id] &&
                  (name = Name.safe_find(params[:chosen_name][:name_id]))
                 [name]
               else
                 Name.find_names_filling_in_authors(@what)
               end
      approved_name = params[:approved_name].to_s.strip_squeeze
      if @names.empty? &&
         (new_name = Name.create_needed_names(approved_name, @what))
        @names = [new_name]
      end
      target_name = @names.first

      # No matches: try to guess.
      if @names.empty?
        @valid_names = Name.suggest_alternate_spellings(@what)
        @suggest_corrections = true

      # If written-in name matches uniquely an existing name:
      elsif target_name && @names.length == 1

        # Merge this name's synonyms with the preferred name's synonyms.
        @name.merge_synonyms(target_name)

        # Change target name to "undeprecated".
        target_name.change_deprecated(false)
        target_name.save_with_log(:log_name_approved,
                                  other: @name.real_search_name)

        # Change this name to "deprecated", set correct spelling, add note.
        @name.change_deprecated(true)
        @name.mark_misspelled(target_name) if @misspelling
        @name.save_with_log(:log_name_deprecated,
                            other: target_name.real_search_name)
        post_comment(:deprecate, @name, @comment) if @comment.present?

        redirect_with_query(action: "show_name", id: @name.id)
      end
    end

    # Form accessible from show_name that lets a user make call this an accepted
    # name, possibly deprecating its synonyms at the same time.
    def approve_name
      pass_query_params
      @name = find_or_goto_index(Name, params[:id].to_s)
      return unless @name
      return if abort_if_name_locked!(@name)

      @approved_names = @name.approved_synonyms
      return unless request.method == "POST"

      deprecate_others
      approve_this_one
      post_approval_comment
      redirect_with_query(@name.show_link_args)
    end

    def abort_if_name_locked!(name)
      return false if !name.locked || in_admin_mode?

      flash_error(:permission_denied.t)
      redirect_back_or_default("/")
    end

    def deprecate_others
      return unless params[:deprecate] && params[:deprecate][:others] == "1"

      @others = []
      @name.approved_synonyms.each do |n|
        n.change_deprecated(true)
        n.save_with_log(:log_name_deprecated, other: @name.real_search_name)
        @others << n.real_search_name
      end
    end

    def approve_this_one
      @name.change_deprecated(false)
      tag = :log_approved_by
      args = {}
      if @others.any?
        tag = :log_name_approved
        args[:other] = @others.join(", ")
      end
      @name.save_with_log(tag, args)
    end

    def post_approval_comment
      return unless params[:comment] && params[:comment][:comment]

      comment = params[:comment][:comment].to_s.strip_squeeze
      return unless comment != ""

      post_comment(:approve, @name, comment)
    end

    # Helper used by change_synonyms.  Deprecates a single name.  Returns true
    # if it worked.  Flashes an error and returns false if it fails for whatever
    # reason.
    def deprecate_synonym(name)
      return true if name.deprecated

      begin
        name.change_deprecated(true)
        name.save_with_log(:log_deprecated_by)
      rescue RuntimeError => e
        flash_error(e.to_s) if e.present?
        false
      end
    end

    # If changing the synonyms of a name that already has synonyms, the user is
    # presented with a list of "existing synonyms".  This is a list of check-
    # boxes.  They all start out checked.  If the user unchecks one, then that
    # name is removed from this synonym.  If the user unchecks several, then a
    # new synonym is created to synonymize all those names.
    def split_off_desynonymized_names(main_name, checks)
      first_group = main_name.synonyms
      other_group = first_group.select do |n|
        (n != main_name) && (checks[n.id.to_s] == "0")
      end
      return if other_group.empty?

      pick_one = other_group.shift
      pick_one.clear_synonym
      other_group.each { |n| pick_one.transfer_synonym(n) }
      main_name.clear_synonym if main_name.reload.synonyms.count <= 1
    end

    def dump_sorter(sorter)
      logger.warn(
        "tranfer_synonyms: only_single_names or only_approved_synonyms is false"
      )
      logger.warn("New names:")
      sorter.new_line_strs.each do |n|
        logger.warn(n)
      end
      logger.warn("\nSingle names:")
      sorter.single_line_strs.each do |n|
        logger.warn(n)
      end
      logger.warn("\nMultiple names:")
      sorter.multiple_line_strs.each do |n|
        logger.warn(n)
      end
      if sorter.chosen_names
        logger.warn("\nChosen names:")
        sorter.chosen_names.each do |n|
          logger.warn(n)
        end
      end
      logger.warn("\nSynonym names:")
      sorter.all_synonyms.map(&:id).each do |n|
        logger.warn(n)
      end
    end

    # Post a comment after approval or deprecation if the user entered one.
    def post_comment(action, name, message)
      summary = :"name_#{action}_comment_summary".l
      Comment.create!(target: name,
                      summary: summary,
                      comment: message)
    end
  end
end

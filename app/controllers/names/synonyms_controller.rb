# frozen_string_literal: true

#  change_synonyms::             Change list of synonyms for a name.
module Names
  class SynonymsController < ApplicationController
    include Names::Synonyms::SharedPrivateMethods

    before_action :login_required

    ############################################################################
    #
    #  :section: Synonymy
    #
    ############################################################################

    # Form accessible from show_name that lets a user review all the synonyms
    # of a name, removing others, writing in new, etc.
    def edit
      pass_query_params
      return unless find_name!
      return if abort_if_name_locked!(@name)

      init_ivars_for_edit
    end

    def update
      pass_query_params

      return unless find_name!
      return if abort_if_name_locked!(@name)

      init_ivars_for_edit
      change_synonyms(prepare_name_sorter)
    end

    private

    def find_name!
      @name = find_or_goto_index(Name, params[:id].to_s)
    end

    def init_ivars_for_edit
      @list_members      = nil
      @new_names         = nil
      @synonym_name_ids  = []
      @proposed_synonyms = []
      @deprecate_all     = true
    end

    def prepare_name_sorter
      list = params[:synonym_members].strip_squeeze
      @deprecate_all = (params[:deprecate_all] == "1")

      # Create any new names that have been approved.
      construct_approved_names(list, params[:approved_names], @deprecate_all)

      # Parse the write-in list of names.
      sorter = NameSorter.new
      sorter.sort_names(list)
      sorter.append_approved_synonyms(params[:approved_synonyms])
      sorter
    end

    def change_synonyms(sorter)
      # Are any names unrecognized (only unapproved names will still be
      # unrecognized at this point) or ambiguous? If so, dump to logger
      if !sorter.only_single_names
        dump_sorter(sorter)
      # Has the user NOT had a chance to choose from among the synonyms of any
      # names they've written in?
      elsif !sorter.only_approved_synonyms
        flash_notice(:name_change_synonyms_confirm.t)
      else
        success = deprecate_other_names(sorter)
        return redirect_to(name_path(@name.id, q: get_query_param)) if success

        flash_object_errors(@name)
        flash_object_errors(@name.synonym)
      end

      re_render_edit_form(sorter)
    end

    def deprecate_other_names(sorter)
      # Go through list of all synonyms for this name and written-in names.
      # Exclude any names that have un-checked check-boxes: newly written-in
      # names will not have a check-box yet, names written-in in previous
      # attempt to submit this form will have checkboxes and therefore must
      # be checked to proceed -- the default initial state.
      proposed_synonym_ids = params[:proposed_synonyms] || {}
      sorter.all_synonyms.each do |n|
        # It is possible these names may be changed by transfer_synonym,
        # but these *instances* will not reflect those changes, so reload.
        if proposed_synonym_ids[n.id.to_s] != "0"
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
          # Already flashed error message.
          success = false unless deprecate_synonym(n)
        end
      end

      success
    end

    def re_render_edit_form(sorter)
      @list_members      = sorter.all_line_strs.join("\r\n")
      @new_names         = sorter.new_name_strs.uniq
      @synonym_name_ids  = sorter.all_synonyms.map(&:id)
      @proposed_synonyms = @synonym_name_ids.filter_map do |id|
        Name.safe_find(id)
      end
      render(:edit, location: edit_name_synonyms_path(@name.id))
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
      main_name.clear_synonym if main_name.reload.synonyms.size <= 1
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
  end
end

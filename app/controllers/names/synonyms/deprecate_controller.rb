# frozen_string_literal: true

# deprecate_name
module Names::Synonyms
  class DeprecateController < ApplicationController
    before_action :login_required
    before_action :pass_query_params

    # Form accessible from show_name that lets the user deprecate a name
    # in favor of another name.
    def new
      return unless find_name!
      return if abort_if_name_locked!(@name)

      init_params_for_new
      init_ivars_for_new
    end

    def create
      return unless find_name!

      return if abort_if_name_locked!(@name)

      init_params_for_new
      init_ivars_for_new

      return unless we_have_a_what!

      # Find the chosen preferred name (and alternates).
      try_to_set_names_from_chosen_name
      try_to_set_names_from_approved_name

      target_name = @names.first
      # No matches: try to guess.
      if @names.empty?
        suggest_alternate_spellings

      # If written-in name matches uniquely an existing name:
      elsif target_name && @names.length == 1
        deprecate_and_post_comment(target_name)
        redirect_to(name_path(@name.id, q: get_query_param))
      else
        # TODO: Flash a custom message about ambiguous name?
        # :api_ambiguous_name.l is kind of similar
        flash_warning(:api_ambiguous_name.t)
        render_new
      end
    end

    private

    def we_have_a_what!
      return true if @given_name.present?

      flash_error(:runtime_name_deprecate_must_choose.t)
      render_new
      false
    end

    def render_new
      render(:new, location: form_to_deprecate_synonym_of_name_path)
    end

    def suggest_alternate_spellings
      @valid_names = Name.suggest_alternate_spellings(@given_name)
      @suggest_corrections = true
      render_new
    end

    def init_params_for_new
      # These parameters aren't always provided.
      params[:chosen_name] ||= {}
      params[:is]          ||= {}
    end

    def init_ivars_for_new
      @given_name = params[:proposed_name].to_s.strip_squeeze
      @comment          = params[:comment].to_s.strip_squeeze
      @list_members     = nil
      @new_names        = []
      @synonym_name_ids = []
      @synonym_names    = []
      @deprecate_all    = "1"
      @names            = []
      @misspelling      = (params[:is][:misspelling] == "1")
    end

    def try_to_set_names_from_chosen_name
      @names = if params[:chosen_name][:name_id] &&
                  (name = Name.safe_find(params[:chosen_name][:name_id]))
                 [name]
               else
                 Name.find_names_filling_in_authors(@given_name)
               end
    end

    def try_to_set_names_from_approved_name
      approved_name = params[:approved_name].to_s.strip_squeeze
      if @names.empty? &&
         (new_name = Name.create_needed_names(approved_name, @given_name))
        @names = [new_name]
      end
    end

    def deprecate_and_post_comment(target_name)
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
    end

    include Names::Synonyms::SharedPrivateMethods
  end
end

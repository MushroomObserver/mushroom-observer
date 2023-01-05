# frozen_string_literal: true

# deprecate_name
module Names::Synonyms
  class DeprecateController < ApplicationController
    before_action :login_required

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

        redirect_to(name_path(@name.id, q: get_query_param))
      end
    end

    include Names::Synonyms::SharedPrivateMethods
  end
end

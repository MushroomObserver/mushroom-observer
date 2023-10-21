# frozen_string_literal: true

# approve_name
module Names::Synonyms
  class ApproveController < ApplicationController
    before_action :login_required

    # Form accessible from show_name that lets a user make call this an accepted
    # name, possibly deprecating its synonyms at the same time.
    def new
      pass_query_params
      return unless find_name!
      return if abort_if_name_locked!(@name)

      @approved_names = @name.approved_synonyms
    end

    def create
      pass_query_params
      return unless find_name!
      return if abort_if_name_locked!(@name)

      @approved_names = @name.approved_synonyms

      deprecate_others
      approve_this_one
      post_approval_comment
      redirect_with_query(@name.show_link_args)
    end

    private

    def render_new
      render(:new, location: approve_name_synonym_form_path)
    end

    def deprecate_others
      return false unless params[:deprecate_others] == "1"

      @others = []
      @name.approved_synonyms.each do |n|
        n.change_deprecated(true)
        n.save_with_log(:log_name_deprecated, other: @name.real_search_name)
        @others << n.real_search_name
      end
      true
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
      return unless params[:comment]

      comment = params[:comment].to_s.strip_squeeze
      return unless comment != ""

      post_comment(:approve, @name, comment)
    end

    include Names::Synonyms::SharedPrivateMethods
  end
end

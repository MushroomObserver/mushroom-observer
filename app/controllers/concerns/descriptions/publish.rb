# frozen_string_literal: true

#  publish_description::
module Descriptions::Publish
  extend ActiveSupport::Concern

  included do
    # Publish a draft description.  If the name has no description, just turn
    # the draft into a public description and make it the default.  If the name
    # has a default description try to merge the draft into it.  If there is a
    # conflict bring up the edit_description form to let the user do the merge.
    def update
      return unless (draft = find_description!(params[:id].to_s))

      parent = draft.parent
      old = parent.description

      # Must be admin on the draft in order for this to work.  (Must be able
      # to delete the draft after publishing it.)
      if !in_admin_mode? && !draft.is_admin?(@user)
        flash_error(:runtime_edit_description_denied.t)
        redirect_to(parent.show_link_args)

      # Can't merge it into itself!
      elsif old == draft
        flash_error(:runtime_description_already_default.t)
        redirect_to(draft.show_link_args)

      # I've temporarily decided to always just turn it into a public desc.
      # User can then merge by hand if public desc already exists.
      else
        draft.source_type = "public"
        draft.source_name = ""
        draft.project     = nil
        draft.admin_groups.clear
        draft.admin_groups << UserGroup.reviewers
        draft.writer_groups.clear
        draft.writer_groups << UserGroup.all_users
        draft.reader_groups.clear
        draft.reader_groups << UserGroup.all_users
        draft.save
        parent.log(:log_published_description,
                   user: @user.login,
                   name: draft.unique_partial_format_name,
                   touch: true)
        parent.description = draft
        parent.save
        redirect_to(parent.show_link_args)
      end
    end

    include ::Descriptions
  end
end

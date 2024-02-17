# frozen_string_literal: true

#
#  = Descriptions Concern
#
#  This is a module that is included by all controllers that deal with
#  descriptions.  (Just LocationsController and NamesController right now.)
#
#  == Actions
#   L = login required
#   R = root required
#   V = has view
#   P = prefetching allowed
#
#
#  == Helpers
#  find_description!::                  Look up a description based on id and
#                                       controller name. (Has to be local def)
#  initialize_description_source::      Initialize source info before serving
#                                       creation form.
#  initialize_description_permissions:: Initialize permissions of new
#                                       Description.
#  check_description_edit_permission::  Double check that no illegal changes are
#                                       being made.
#
################################################################################

module Descriptions
  extend ActiveSupport::Concern

  included do
    ############################################################################
    #
    #  :section Helpers for show
    #
    ############################################################################

    def description_canonical_url(description)
      "#{MO.http_domain}/#{description.parent.type_tag.to_s.pluralize}/" \
        "descriptions/#{description.id}"
    end

    def description_parent_exists?(parent)
      return true if parent

      flash_error(:runtime_name_for_description_not_found.t)
      # parent index:
      redirect_to(send(:"#{parent.type_tag.to_s.pluralize}_path"))
      false
    end

    def user_has_permission_to_see_description?
      return true if in_admin_mode? || @description.is_reader?(@user)

      if @description.source_type == :project
        flash_error(:runtime_show_draft_denied.t)
      else
        flash_error(:runtime_show_description_denied.t)
      end
      redirect_to_parent_or_project
    end

    def redirect_to_parent_or_project
      if @description.project
        redirect_to(project_path(@description.project_id))
      else
        redirect_to(add_query_param(@description.parent.show_link_args))
      end
    end

    def users_projects_which_dont_have_desc_of_this(parent)
      return [] unless @user

      @user&.projects_member&.select do |project|
        parent.descriptions.none? { |d| d.belongs_to_project?(project) }
      end
    end

    ############################################################################
    #
    #  :section Helpers for Create/Edit
    #
    ############################################################################

    # Initialize source info before serving creation form.
    def initialize_description_source
      @description.license = @user.license

      # Creating a draft.
      if params[:project].present?
        project = Project.find(params[:project])
        if @user.in_group?(project.user_group)
          @description.source_type  = "project"
          @description.source_name  = project.title
          @description.project      = project
          @description.public       = false
          @description.public_write = false
        else
          flash_error(:runtime_create_draft_create_denied.
                        t(title: project.title))
          redirect_to(project_path(project.id))
        end

      # Cloning an existing description. Only occurs on names?
      elsif params[:clone].present?
        clone = find_description!(params[:clone])
        if in_admin_mode? || clone.is_reader?(@user)
          @description.all_notes = clone.all_notes
          @description.source_type  = "user"
          @description.source_name  = ""
          @description.project_id   = nil
          @description.public       = false
          @description.public_write = false
        else
          flash_error(:runtime_description_private.t)
          redirect_to(name_path(@description.parent_id))
        end

      # Otherwise default to "public" description.
      else
        @description.source_type  = "public"
        @description.source_name  = ""
        @description.project_id   = nil
        @description.public       = true
        @description.public_write = true
      end
    end

    # This is called right after a description is created.  It sets the admin,
    # read and write permissions for a new description.
    def initialize_description_permissions
      read  = @description.public
      write = (@description.public_write == "1")
      case @description.source_type

      # Creating standard "public" description.
      when "public"
        flash_warning(:runtime_description_public_read_wrong.t)  unless read
        flash_warning(:runtime_description_public_write_wrong.t) unless write
        @description.reader_groups << UserGroup.all_users
        @description.writer_groups << UserGroup.all_users
        @description.admin_groups << UserGroup.reviewers
        @description.public = true
        @description.save

      # Creating draft for project.
      when "project"
        project = @description.project
        if read
          @description.reader_groups << UserGroup.all_users
        else
          @description.reader_groups << project.user_group
          @description.writer_groups << UserGroup.one_user(@user)
        end
        if write
          @description.writer_groups << UserGroup.all_users
        else
          @description.writer_groups << project.admin_group
          @description.writer_groups << UserGroup.one_user(@user)
        end
        @description.admin_groups << project.admin_group
        @description.admin_groups << UserGroup.one_user(@user)

      # Creating personal description, or entering one from a specific source.
      when "source", "user"
        @description.reader_groups << if read
                                        UserGroup.all_users
                                      else
                                        UserGroup.one_user(@user)
                                      end
        @description.writer_groups << if write
                                        UserGroup.all_users
                                      else
                                        UserGroup.one_user(@user)
                                      end
        @description.admin_groups << UserGroup.one_user(@user)

      else
        raise(:runtime_invalid_source_type.t(
                value: @description.source_type.inspect
              ))
      end
    end

    # Make sure user is allowed to make the changes they are trying to make.
    # check_description_edit_permission is partly broken.
    # It, LocationController, and NameController need repairs.
    # See https://www.pivotaltracker.com/story/show/174737948
    def check_description_edit_permission!
      okay = true

      # Fail completely if they don't even have write permission.
      unless in_admin_mode? || @description.writer?(@user)
        flash_error(:runtime_edit_description_denied.t)
        if in_admin_mode? || @description.is_reader?(@user)
          redirect_to(object_path(@description))
        else
          redirect_to(object_path(@description.parent))
        end

        okay = false
      end

      filter_illegal_changes

      okay
    end

    # Just ignore illegal changes otherwise.  Form should prevent these,
    # anyway, but user could try to get sneaky and make changes via URL.
    # check_description_edit_permission is partly broken.
    # It, LocationController, and NameController need repairs.
    # See https://www.pivotaltracker.com/story/show/174737948
    # Attempted fix by Nimmo 04102022 (changed is_a?(Hash), cause it ain't)
    def filter_illegal_changes
      return unless params[:description].is_a?(ActionController::Parameters)

      root = in_admin_mode?
      admin = @description.is_admin?(@user)
      author = @description.author?(@user)

      params[:description].delete(:source_type) unless root
      unless root ||
             ((admin || author) &&
               # originally was
               # (desc.source_type != "project" &&
               #  desc.source_type != "project"))
               # see https://www.pivotaltracker.com/story/show/174566300
               @description.source_type != "project")
        params[:description].delete(:source_name)
      end
      params[:description].delete(:license_id) unless root || admin || author
    end

    # Modify permissions on an existing Description based on two over-simplified
    # "public readable" and "public writable" checkboxes.  Makes changes to the
    # UserGroup's.
    # desc::      Description object, with +public+ and +public_write+ updated.
    def modify_description_permissions
      old_read = @description.public_was
      new_read = @description.public
      old_write = @description.public_write_was
      new_write = (@description.public_write == "1")

      # Ensure these special types don't change,
      case @description.source_type
      when "public"
        flash_warning(:runtime_description_public_read_wrong.t) unless new_read
        unless new_write
          flash_warning(:runtime_description_public_write_wrong.t)
        end
        new_read  = true
        new_write = true
      when "foreign"
        flash_warning(:runtime_description_foreign_read_wrong.t) unless new_read
        flash_warning(:runtime_description_foreign_write_wrong.t) if new_write
        new_read  = true
        new_write = false
      end

      new_readers = []
      new_writers = []

      # "Public" means "all users" group.
      if !old_read && new_read
        new_readers << UserGroup.all_users
        @description.public = true
      end
      new_writers << UserGroup.all_users if !old_write && new_write

      # "Not Public" means only the owner...
      if old_read && !new_read
        new_readers << UserGroup.one_user(@description.user)
      end
      if old_write && !new_write
        new_writers << UserGroup.one_user(@description.user)
      end

      # ...except in the case of projects.
      if (@description.source_type == "project") &&
         (project = @description.project)
        if old_read && !new_read
          # Add project members to readers.
          new_readers << project.user_group
        end
        if old_write && !new_write
          # Add project admins to writers.
          new_writers << project.admin_group
        end
      end
    end

    def object_path(object)
      { controller: object.show_controller,
        action: object.show_action,
        id: object.id }
    end

    def object_path_with_query(object)
      { controller: object.show_controller,
        action: object.show_action,
        id: object.id, q: get_query_param }
    end

    def find_licenses
      @licenses = License.current_names_and_ids
    end

    # Log action in parent
    def log_description_created
      @description.parent.log(:log_description_created,
                              user: @user.login, touch: true,
                              name: @description.unique_partial_format_name)
    end

    def log_description_updated
      # Log action to parent name.
      @description.parent.log(:log_description_updated,
                              user: @user.login, touch: true,
                              name: @description.unique_partial_format_name)
    end

    # Delete old description after resolving conflicts of merge.
    def resolve_merge_conflicts_and_delete_old_description
      if (params[:delete_after] == "true") &&
         (old_desc = @description.class.safe_find(params[:old_desc_id]))
        if !in_admin_mode? && !old_desc.is_admin?(@user)
          flash_warning(:runtime_description_merge_delete_denied.t)
        else
          flash_notice(:runtime_description_merge_deleted.
                          t(old: old_desc.partial_format_name))
          log_description_merged(old_desc)
          old_desc.destroy
        end
      end
    end

    # Log merge to parent.
    def log_description_merged(old_desc)
      @description.parent.log(:log_object_merged_by_user,
                              user: @user.login, touch: true,
                              from: old_desc.unique_partial_format_name,
                              to: @description.unique_partial_format_name)
    end

    def check_delete_permission_flash_and_redirect
      if in_admin_mode? || @description.is_admin?(@user)
        flash_notice(:runtime_destroy_description_success.t)
        log_description_destroyed
        @description.destroy
        redirect_to(add_query_param(@description.parent.show_link_args))
      else
        flash_error(:runtime_destroy_description_not_admin.t)
        redirect_if_description_not_destroyed
      end
    end

    def redirect_if_description_not_destroyed
      if in_admin_mode? || @description.is_reader?(@user)
        redirect_to(add_query_param(@description.show_link_args))
      else
        redirect_to(add_query_param(@description.parent.show_link_args))
      end
    end

    def log_description_destroyed
      @description.parent.log(:log_description_destroyed,
                              user: @user.login, touch: true,
                              name: @description.unique_partial_format_name)
    end
  end
end

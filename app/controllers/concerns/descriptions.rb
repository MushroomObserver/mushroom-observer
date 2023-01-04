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
#  find_description::                   Look up a description based on id and
#                                       controller name.
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
    #  :section Helpers
    #
    ############################################################################

    # Look up a name or location description by id, using the controller name
    # to decide which kind.
    def find_description(id)
      if instance_of?(NameController)
        find_or_goto_index(NameDescription, id)
      else
        find_or_goto_index(LocationDescription, id)
      end
    end

    # Initialize source info before serving creation form.
    def initialize_description_source(desc)
      desc.license = @user.license

      # Creating a draft.
      if params[:project].present?
        project = Project.find(params[:project])
        if @user.in_group?(project.user_group)
          desc.source_type  = "project"
          desc.source_name  = project.title
          desc.project      = project
          desc.public       = false
          desc.public_write = false
        else
          flash_error(:runtime_create_draft_create_denied.
                        t(title: project.title))
          redirect_to(controller: "project", action: "show_project",
                      id: project.id)
        end

      # Cloning an existing description.
      elsif params[:clone].present?
        clone = find_description(params[:clone])
        if in_admin_mode? || clone.is_reader?(@user)
          desc.all_notes = clone.all_notes
          desc.source_type  = "user"
          desc.source_name  = ""
          desc.project_id   = nil
          desc.public       = false
          desc.public_write = false
        else
          flash_error(:runtime_description_private.t)
          redirect_to(action: "show_name", id: desc.parent_id)
        end

      # Otherwise default to "public" description.
      else
        desc.source_type  = "public"
        desc.source_name  = ""
        desc.project_id   = nil
        desc.public       = true
        desc.public_write = true
      end
    end

    # This is called right after a description is created.  It sets the admin,
    # read and write permissions for a new description.
    def initialize_description_permissions(desc)
      read  = desc.public
      write = (desc.public_write == "1")
      case desc.source_type

      # Creating standard "public" description.
      when "public"
        flash_warning(:runtime_description_public_read_wrong.t)  unless read
        flash_warning(:runtime_description_public_write_wrong.t) unless write
        desc.reader_groups << UserGroup.all_users
        desc.writer_groups << UserGroup.all_users
        desc.admin_groups << UserGroup.reviewers
        desc.public = true
        desc.save

      # Creating draft for project.
      when "project"
        project = desc.project
        if read
          desc.reader_groups << UserGroup.all_users
        else
          desc.reader_groups << project.user_group
          desc.writer_groups << UserGroup.one_user(@user)
        end
        if write
          desc.writer_groups << UserGroup.all_users
        else
          desc.writer_groups << project.admin_group
          desc.writer_groups << UserGroup.one_user(@user)
        end
        desc.admin_groups << project.admin_group
        desc.admin_groups << UserGroup.one_user(@user)

      # Creating personal description, or entering one from a specific source.
      when "source", "user"
        desc.reader_groups << if read
                                UserGroup.all_users
                              else
                                UserGroup.one_user(@user)
                              end
        desc.writer_groups << if write
                                UserGroup.all_users
                              else
                                UserGroup.one_user(@user)
                              end
        desc.admin_groups << UserGroup.one_user(@user)

      else
        raise(:runtime_invalid_source_type.t(value: desc.source_type.inspect))
      end
    end

    # Make sure user is allowed to make the changes they are trying to make.
    def check_description_edit_permission(desc, params)
      okay = true

      # Fail completely if they don't even have write permission.
      unless in_admin_mode? || desc.writer?(@user)
        flash_error(:runtime_edit_description_denied.t)
        if in_admin_mode? || desc.is_reader?(@user)
          redirect_to(action: desc.show_action, id: desc.id)
        else
          redirect_to(action: desc.parent.show_action, id: desc.parent_id)
        end
        okay = false
      end

      # Just ignore illegal changes otherwise.  Form should prevent these,
      # anyway, but user could try to get sneaky and make changes via URL.
      # check_description_edit_permission is partly broken.
      # It, LocationController, and NameController need repairs.
      # See https://www.pivotaltracker.com/story/show/174737948
      if params.is_a?(Hash)
        root = in_admin_mode?
        admin = desc.is_admin?(@user)
        author = desc.author?(@user)

        params.delete(:source_type) unless root
        unless root ||
               ((admin || author) &&
                 # originally was
                 # (desc.source_type != "project" &&
                 #  desc.source_type != "project"))
                 # see https://www.pivotaltracker.com/story/show/174566300
                 desc.source_type != "project")
          params.delete(:source_name)
        end
        params.delete(:license_id) unless root || admin || author
      end

      okay
    end

    # Modify permissions on an existing Description based on two over-simplified
    # "public readable" and "public writable" checkboxes.  Makes changes to the
    # UserGroup's.
    # desc::      Description object, with +public+ and +public_write+ updated.
    def modify_description_permissions(desc)
      old_read = desc.public_was
      new_read = desc.public
      old_write = desc.public_write_was
      new_write = (desc.public_write == "1")

      # Ensure these special types don't change,
      case desc.source_type
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
        desc.public = true
      end
      new_writers << UserGroup.all_users if !old_write && new_write

      # "Not Public" means only the owner...
      new_readers << UserGroup.one_user(desc.user) if old_read && !new_read
      new_writers << UserGroup.one_user(desc.user) if old_write && !new_write

      # ...except in the case of projects.
      if (desc.source_type == "project") &&
         (project = desc.project)
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
  end
end

# frozen_string_literal: true

#  adjust_permissions::
#  flash_description_changes::          Show changes made to permissions.
#  group_name::                         Return human-readable name of UserGroup.
#  modify_description_permissions::     Update blah_groups based on changed to
#                                       two public checkboxes.
#  update_writein::                     Update the permissions for a write-in
#                                       user or group.
#  update_groups::                      Update one type of permissions for a
#                                       Hash of groups.
#  update_group::                       Update 1 type of permission for 1 group.

module Descriptions::Permissions
  extend ActiveSupport::Concern

  included do
    # Form to adjust permissions on a description.
    def edit
      pass_query_params
      return unless (@description = find_description!(params[:id].to_s))

      done = false
      # Doesn't have permission.
      if !in_admin_mode? && !@description.is_admin?(@user)
        flash_error(:runtime_description_adjust_permissions_denied.t)
        done = true

      # These types have fixed permissions.
      elsif %w[public foreign].include?(@description.source_type) &&
            !in_admin_mode?
        flash_error(:runtime_description_permissions_fixed.t)
        done = true
      end
      @data = nil

      if done
        redirect_to(object_path_with_query(@description))

      # Gather list of all the groups, authors, editors and owner.
      # If the user wants more they can write them in.
      else
        gather_list_of_groups
      end
    end

    def update
      pass_query_params
      return unless (@description = find_description!(params[:id].to_s))

      done = false
      # Doesn't have permission.
      if !in_admin_mode? && !@description.is_admin?(@user)
        flash_error(:runtime_description_adjust_permissions_denied.t)
        done = true

      # These types have fixed permissions.
      elsif %w[public foreign].include?(@description.source_type) &&
            !in_admin_mode?
        flash_error(:runtime_description_permissions_fixed.t)
        done = true

      # We're on.
      else
        old_readers = @description.reader_groups.sort_by(&:id)
        old_writers = @description.writer_groups.sort_by(&:id)
        old_admins  = @description.admin_groups.sort_by(&:id)

        # Update permissions on list of users and groups at the top.
        update_groups(@description, :readers, params[:group_reader])
        update_groups(@description, :writers, params[:group_writer])
        update_groups(@description, :admins,  params[:group_admin])

        # Look up write-ins and adjust their permissions.
        done = assemble_data

        # Were any changes made?
        new_readers = @description.reader_groups.sort_by(&:id)
        new_writers = @description.writer_groups.sort_by(&:id)
        new_admins  = @description.admin_groups.sort_by(&:id)
        if (old_readers != new_readers) ||
           (old_writers != new_writers) ||
           (old_admins != new_admins)

          # Give feedback to assure user that their changes were made.
          flash_description_changes(old_readers, new_readers, :reader)
          flash_description_changes(old_writers, new_writers, :writer)
          flash_description_changes(old_admins,  new_admins,  :admin)

          # Keep the "public" flag updated.
          public = @description.reader_groups.include?(UserGroup.all_users)
          if @description.public != public
            @description.public = public
            @description.save
          end

          @description.parent.log(:log_changed_permissions,
                                  user: @user.login, touch: false,
                                  name: @description.unique_partial_format_name)
        else
          flash_notice(:runtime_description_adjust_permissions_no_changes.t)
        end
      end

      if done
        redirect_to(object_path_with_query(@description))

      # Gather list of all the groups, authors, editors and owner.
      # If the user wants more they can write them in.
      else
        gather_list_of_groups
      end
    end

    def gather_list_of_groups
      @groups = (
        [UserGroup.all_users] +
        @description.admin_groups.sort_by(&:name) +
        @description.writer_groups.sort_by(&:name) +
        @description.reader_groups.sort_by(&:name) +
        [UserGroup.reviewers]
      ) + (
        [@description.user] +
        @description.authors.sort_by(&:login) +
        @description.editors.sort_by(&:login) +
        [@user]
      ).map { |user| UserGroup.one_user(user) }
      @groups.uniq!
      @groups = @groups.reject { |g| g.name.match(/^user \d+$/) } +
                @groups.select { |g| g.name.match(/^user \d+$/) }
    end

    def assemble_data
      @data = [nil]
      done = true
      params[:writein_name].keys.sort.each do |n|
        name   = begin
                   params[:writein_name][n].to_s
                 rescue StandardError
                   ""
                 end
        reader = begin
                   params[:writein_reader][n] == "1"
                 rescue StandardError
                   false
                 end
        writer = begin
                   params[:writein_writer][n] == "1"
                 rescue StandardError
                   false
                 end
        admin  = begin
                   params[:writein_admin][n] == "1"
                 rescue StandardError
                   false
                 end

        next unless name.present? &&
                    !update_writein(@description, name, reader, writer,
                                    admin)

        @data << { name: name, reader: reader, writer: writer,
                   admin: admin }
        flash_error(:runtime_description_user_not_found.t(name: name))
        done = false
      end
      done
    end

    # Throw up some flash notices to reassure user that we did in fact make the
    # changes they wanted us to make.
    def flash_description_changes(old_groups, new_groups, type)
      (new_groups - old_groups).each do |group|
        name = group_name(group)
        flash_notice(:"runtime_description_added_#{type}".t(name: name))
      end
      (old_groups - new_groups).each do |group|
        name = group_name(group)
        flash_notice(:"runtime_description_removed_#{type}".t(name: name))
      end
    end

    # Return name of group or user if it's a one-user group.
    def group_name(group)
      return(:adjust_permissions_all_users.t) if group.name == "all users"
      return(:REVIEWERS.t) if group.name == "reviewers"
      return(group.users.first.legal_name) if /^user \d+$/.match?(group.name)

      group.name
    end

    # Update the permissions for a write-in.
    def update_writein(desc, name, reader, writer, admin)
      result = true
      group = if name =~ /^(.*\S) +<.*>$/
                User.find_by(login: Regexp.last_match(1))
              else
                User.find_by(login: name) ||
                  UserGroup.find_by_name(name)
              end
      group = UserGroup.one_user(group) if group.is_a?(User)
      if group
        update_group(desc, :readers, group, reader)
        update_group(desc, :writers, group, writer)
        update_group(desc, :admins,  group, admin)
      else
        result = false
      end
      result
    end

    # Update the permissions of a given type for the list of pre-filled-in
    # groups.
    def update_groups(desc, type, groups)
      groups.each do |id, val|
        if (group = UserGroup.safe_find(id))
          update_group(desc, type, group, (val == "1"))
        else
          flash_error(:runtime_description_user_not_found.t(name: id))
        end
      end
    end

    # Update one group's permissions of a given type.
    def update_group(desc, type, group, value)
      method = type.to_s.sub(/s$/, "_groups")
      old_value = desc.send(method).include?(group)
      if old_value && !value
        desc.send(method).delete(group)
      elsif !old_value && value
        desc.send(method).push(group)
      end
    end

    include ::Descriptions
  end
end

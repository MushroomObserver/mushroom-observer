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

#  NOTE: The write-in names offer autocomplete, but they currently do not force
#  an autocompleted user, nor do they store a user ID. Admins may type whatever,
#  and the update_writein method will try to find the user by regex.

# SAMPLE PARAMS HASH structure is a bit convoluted.
# You might expect:
# params: {
#   groups: {
#     14: {
#       read: 1,
#       write: 0,
#       admin: 0
#     }
#     1: {
#       read: 0,
#       write: 1,
#       admin: 1
#     }
#     225: {
#       read: 0,
#       write: 0,
#       admin: 1
#     }
#     3333: {
#       read: 0,
#       write: 0,
#       admin: 1
#     }
#   },
#   writeins: {
#     "jason": {
#       read: 0,
#       write: 1,
#       admin: 1
#     }
#   }
# }
#
# but it's like this:
# params: {
#   "utf8"=>"✓",
#   "authenticity_token"=>"2FG9QUb2iCG/FvJLVFpcFBOQVwUKM0jmhP5AUOs",
#   "group_reader"=>{"14"=>"1", "1"=>"0", "225"=>"0", "3333"=>"0"},
#   "group_writer"=>{"14"=>"0", "1"=>"1", "225"=>"0", "3333"=>"0"},
#   "group_admin"=>{"14"=>"0", "1"=>"1", "225"=>"0", "3333"=>"0"},
#   "writein_name"=>{
#     "1"=>"jason", "2"=>"", "3"=>"", "4"=>"", "5"=>"", "6"=>""
#   },
#   "writein_reader"=>{
#     "1"=>"1", "2"=>"0", "3"=>"0", "4"=>"0", "5"=>"0", "6"=>"0"
#   },
#   "writein_writer"=>{
#     "1"=>"1", "2"=>"0", "3"=>"0", "4"=>"0", "5"=>"0", "6"=>"0"
#   },
#   "writein_admin"=>{
#     "1"=>"1", "2"=>"0", "3"=>"0", "4"=>"0", "5"=>"0", "6"=>"0"
#   },
#   "commit"=>"Submit",
#   "q"=>"1m0k8",
#   "id"=>"2490"
# }
# group_ids: (+ user_id if applicable)
# 14    all_users,
# 1     reviewers,
# 225   walt sturgeon (Mycowalt) (author, owner) 369
# 3333  Nimmo (barky) (site admin) 3477
# writeins:
# 139   Jason Hollinger (jason) 252

module Descriptions::Permissions
  extend ActiveSupport::Concern

  # rubocop:disable Metrics/BlockLength
  included do
    # Form to adjust permissions on a description.
    def edit
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
      else
        gather_list_of_groups
      end
    end

    def update
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
        done = change_group_permissions
      end

      if done
        redirect_to(object_path_with_query(@description))
      else
        gather_list_of_groups
        render("new")
      end
    end

    # Return name of group or user if it's a one-user group.
    def group_name(group)
      return(:adjust_permissions_all_users.t) if group.name == "all users"
      return(:REVIEWERS.t) if group.name == "reviewers"
      return(group.users.first.legal_name) if /^user \d+$/.match?(group.name)

      group.name
    end

    private

    # used by :update
    def change_group_permissions
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
      changes_made = ((old_readers != new_readers) ||
                      (old_writers != new_writers) ||
                      (old_admins != new_admins))

      if changes_made
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

      done
    end

    # Gather the list of all user groups that have access to this description.
    # Authors, editors and owner are printed in a table, with checkboxes to
    # adjust their permissions. If the admin wants more they can write them in.
    # Gets hit both on :edit and :update
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

    # used by :update
    # NOTE: the param data is asymmetrical. Unlike the :group_reader etc that
    # are indexed by user_group ID, :writein_reader etc are indexed by row #.
    # The names for each row (used by regex to find an ID) are in a separate
    # array, :writein_name. Every row gets (blank) data even if there's no name.
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
  # rubocop:enable Metrics/BlockLength
end

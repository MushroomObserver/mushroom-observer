# frozen_string_literal: true

# Adds a unique index on user_groups.name -- previously unindexed,
# forcing every UserGroup.find_by_name (all_users/reviewers/one_user)
# to a full table scan (~158K rows: one "user #{id}" group per user,
# plus meta-groups). Names are 1:1 with groups by convention (see
# UserGroup's class doc: "name:: Name of the group, must be unique.");
# this was an oversight, not an intentional gap.
#
# One pre-existing duplicate found in production data: project #231
# ("MMHC Mycoflora Project")'s member group AND admin group were both
# named "MMHC Mycoflora Project". Every other project's admin group
# follows the ".admin" suffix convention (see Project#admin_group vs.
# #user_group) -- this looks like a one-off bug at that project's
# creation (2017-12-27), not an intentional exception. Renamed to
# match the established convention before adding the index, so the
# index can actually be added.
class AddUniqueIndexToUserGroupsName < ActiveRecord::Migration[7.2]
  def up
    rename_duplicate_admin_groups
    add_index(:user_groups, :name, unique: true)
  end

  def down
    remove_index(:user_groups, :name)
  end

  private

  def rename_duplicate_admin_groups
    duplicate_names.each { |name| rename_admin_group_if_duplicated(name) }
  end

  def duplicate_names
    UserGroup.group(:name).having("count(*) > 1").pluck(:name)
  end

  def rename_admin_group_if_duplicated(name)
    ids = UserGroup.where(name: name).pluck(:id)
    project = Project.find_by(admin_group_id: ids)
    return unless project

    project.admin_group.update_column(:name, "#{name}.admin")
  end
end

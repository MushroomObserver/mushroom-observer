# frozen_string_literal: true

# One row per (user_group, user) (#5636). Project#join and
# Project#add_administrator both do `user_group.users << user unless
# user_group.users.member?(user)` -- two concurrent requests (a
# double form-submit on the open-membership join button, say) can
# each find no row and each insert one, same race #4181 fixed for
# project_observations/project_images.
#
# The repair, script/dedupe_user_group_users.rb, removes the existing
# duplicates. The table is small; the index builds online.
class UniqueUserGroupUsers < ActiveRecord::Migration[7.2]
  REPAIR = "bin/rails runner script/dedupe_user_group_users.rb --apply"

  # Copy of the table as this migration needs it, rather than the
  # application's model -- that goes on changing after this migration
  # is written.
  class MigrationUserGroupUser < ActiveRecord::Base
    self.table_name = "user_group_users"
  end

  def up
    refuse_until_repaired
    add_index(:user_group_users, [:user_group_id, :user_id],
              unique: true, name: "index_user_group_users_unique")
  end

  def down
    remove_index(:user_group_users, name: "index_user_group_users_unique")
  end

  private

  def refuse_until_repaired
    duplicates = duplicate_count
    return if duplicates.zero?

    raise(<<~MESSAGE)
      #{duplicates} user_group/user pairs have more than one row, so
      the unique index cannot be added yet.

      Run the repair first, reading its dry run before applying it:
        #{REPAIR.sub(" --apply", "")}
        #{REPAIR}
    MESSAGE
  end

  def duplicate_count
    MigrationUserGroupUser.group(:user_group_id, :user_id).
      having(Arel.star.count.gt(1)).count.size
  end
end

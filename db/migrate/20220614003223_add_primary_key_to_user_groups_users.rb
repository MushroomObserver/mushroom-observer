class AddPrimaryKeyToUserGroupsUsers < ActiveRecord::Migration[6.1]
  def change
    rename_table("user_groups_users", "user_group_users")
    add_column(:user_group_users, :id, :primary_key)
  end
end

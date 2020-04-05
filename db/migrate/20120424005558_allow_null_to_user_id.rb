class AllowNullToUserId < ActiveRecord::Migration[4.2]
  def self.up
    rename_column(:queued_emails, :to_user_id, :to_user_id_old)
    add_column(:queued_emails, :to_user_id, :integer)
    Name.connection.update("update queued_emails set to_user_id=to_user_id_old")
    remove_column(:queued_emails, :to_user_id_old)
  end

  def self.down
    rename_column(:queued_emails,  :to_user_id, :to_user_id_old)
    add_column(:queued_emails, :to_user_id, :integer, default: 0, null: false)
    Name.connection.update("update queued_emails set to_user_id=to_user_id_old")
    remove_column(:queued_emails, :to_user_id_old)
  end
end

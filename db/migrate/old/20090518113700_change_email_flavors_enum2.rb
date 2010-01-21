class ChangeEmailFlavorsEnum2 < ActiveRecord::Migration
  def self.up
    add_column :queued_emails, :flavor_tmp, :enum, :limit => QueuedEmail.all_flavors
    QueuedEmail.connection.update("update queued_emails set flavor_tmp=flavor")
    remove_column :queued_emails, :flavor

    add_column :queued_emails, :flavor, :enum, :limit => QueuedEmail.all_flavors
    QueuedEmail.connection.update("update queued_emails set flavor=flavor_tmp")
    remove_column :queued_emails, :flavor_tmp
  end
end

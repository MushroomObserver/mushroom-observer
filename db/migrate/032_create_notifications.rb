class CreateNotifications < ActiveRecord::Migration
  def self.up
    create_table :notifications do |t|
      t.column :user_id, :integer, :default => 0, :null => false
      t.column :flavor, :enum, :limit => Notification.all_flavors
      t.column :obj_id, :integer
      t.column :note_template, :text
    end
  end

  def self.down
    drop_table :notifications
  end
end

class AddUserNotesLocationImage < ActiveRecord::Migration
  def self.up
    add_column :users, "notes",       :text,    :default => "",  :null => false
    add_column :users, "location_id", :integer, :default => nil, :null => true
    add_column :users, "image_id",    :integer, :default => nil, :null => true
  end

  def self.down
    remove_column :users, "notes"
    remove_column :users, "location_id"
    remove_column :users, "image_id"
  end
end

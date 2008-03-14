class AutoLogin < ActiveRecord::Migration
  def self.up
    add_column :users, "autologin", :boolean, :default => true, :null => false
  end

  def self.down
    remove_column :users, "autologin"
  end
end

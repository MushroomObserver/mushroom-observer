class AddUserMailingAddress < ActiveRecord::Migration
  def self.up
    add_column :users, "mailing_address", :text, :default => "",  :null => false
  end

  def self.down
    remove_column :users, "mailing_address"
  end
end

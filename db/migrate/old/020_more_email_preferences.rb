class MoreEmailPreferences < ActiveRecord::Migration
  def self.up
    add_column :users, "comment_email", :boolean, :default => true, :null => false
    add_column :users, "html_email",    :boolean, :default => true, :null => false
  end

  def self.down
    remove_column :users, "comment_email"
    remove_column :users, "html_email"
  end
end

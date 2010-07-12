class UserEmailOptions < ActiveRecord::Migration
  def self.up
    add_column :users,  "feature_email", :boolean, :default => true, :null => false
    add_column :users,  "commercial_email", :boolean, :default => true, :null => false
    add_column :users,  "question_email", :boolean, :default => true, :null => false
  end

  def self.down
    remove_column :users,  "feature_email"
    remove_column :users,  "commercial_email"
    remove_column :users,  "question_email"
  end
end

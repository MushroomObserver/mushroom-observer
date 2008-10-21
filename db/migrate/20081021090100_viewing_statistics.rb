class ViewingStatistics < ActiveRecord::Migration
  def self.up
    add_column :observations, "num_views", :integer, :default => 0, :null => false
    add_column :observations, "last_view", :datetime
    add_column :images, "num_views", :integer, :default => 0, :null => false
    add_column :images, "last_view", :datetime
    add_column :names, "num_views", :integer, :default => 0, :null => false
    add_column :names, "last_view", :datetime
  end

  def self.down
    remove_column :observations, "num_views"
    remove_column :observations, "last_view"
    remove_column :images, "num_views"
    remove_column :images, "last_view"
    remove_column :names, "num_views"
    remove_column :names, "last_view"
  end
end

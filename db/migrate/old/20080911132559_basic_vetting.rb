class BasicVetting < ActiveRecord::Migration
  def self.up
    add_column :names, :review_status, :enum, :limit => Name.all_review_statuses, :default => :unreviewed, :null => false
    add_column :past_names, :review_status, :enum, :limit => Name.all_review_statuses, :default => :unreviewed, :null => false
    add_column :namings, :review_status, :enum, :limit => Name.all_review_statuses, :default => :unreviewed, :null => false
    add_column :images, :quality, :enum, :limit => Image.all_qualities, :default => :unreviewed, :null => false
  end

  def self.down
    remove_column :names, :review_status
    remove_column :namings, :review_status
    remove_column :images, :quality
  end
end

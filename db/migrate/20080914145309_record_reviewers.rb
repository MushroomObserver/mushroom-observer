class RecordReviewers < ActiveRecord::Migration
  def self.up
    add_column :names, :reviewer_id, :integer, :default => nil, :null => true
    add_column :names, :last_review, :datetime
    add_column :images, :reviewer_id, :integer, :default => nil, :null => true
  end

  def self.down
    remove_column :names, :reviewer_id
    remove_column :names, :last_review
    remove_column :images, :reviewer_id
  end
end

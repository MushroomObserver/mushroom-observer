class VerifiedForUser < ActiveRecord::Migration
  def self.up
    add_column :users,  "verified", :datetime
  end

  def self.down
    remove_column :users,  "verified"
  end
end

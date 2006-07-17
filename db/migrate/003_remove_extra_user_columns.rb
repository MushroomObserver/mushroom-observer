class RemoveExtraUserColumns < ActiveRecord::Migration
  def self.up
    remove_column :images, "owner"
    remove_column :observations, "who"
  end
  
  def self.down
    add_column :images,  "owner", :string, :limit => 100
    add_column :observations,  "who", :string, :limit => 100
  end
end

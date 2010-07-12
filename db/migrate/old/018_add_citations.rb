class AddCitations < ActiveRecord::Migration
  def self.up
    add_column :names,  "citation", :string, :limit => 200
    add_column :past_names,  "citation", :string, :limit => 200
  end

  def self.down
    remove_column :names,  "citation"
    remove_column :past_names,  "citation"
  end
end

require 'string_extensions'

class AddLocationSearchName < ActiveRecord::Migration
  def self.up
    add_column :locations, "search_name", :string, :limit => 200
    for loc in Location.find(:all)
      loc.set_search_name
      loc.save
    end
  end

  def self.down
    remove_column :locations, "search_name"
  end
end

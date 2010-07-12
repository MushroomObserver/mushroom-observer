class AddLocationFormatPref < ActiveRecord::Migration
  def self.up
    add_column :locations_versions, :name, :string, :limit => 200
    Location.connection.update %(
      UPDATE locations_versions SET name = display_name
    )
    remove_column :locations_versions, :display_name
    add_column :locations, :name, :string, :limit => 200
    Location.connection.update %(
      UPDATE locations SET name = display_name
    )
    remove_column :locations, :display_name
    add_column :users, :location_format, :enum, :limit => [:postal, :scientific], :default => :postal
  end

  def self.down
    remove_column :users, :location_format
    add_column :locations, :display_name, :string, :limit => 200
    Location.connection.update %(
      UPDATE locations SET display_name = name
    )
    remove_column :locations, :name
    add_column :locations_versions, :display_name, :string, :limit => 200
    Location.connection.update %(
      UPDATE locations_versions SET display_name = name
    )
    remove_column :locations_versions, :name
  end
end

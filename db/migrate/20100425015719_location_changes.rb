# encoding: utf-8
class LocationChanges < ActiveRecord::Migration[4.2]
  def self.up
    add_column :locations_versions, :name, :string, limit: 200
    Location.connection.update %(
      UPDATE locations_versions SET name = display_name
    )
    remove_column :locations_versions, :display_name
    add_column :locations, :name, :string, limit: 200
    Location.connection.update %(
      UPDATE locations SET name = display_name
    )
    remove_column :locations, :display_name
    add_column :users, :location_format, :enum, limit: [:postal, :scientific], default: :postal

    add_column :locations, :notes, :text
    add_column :locations_versions, :notes, :text

    remove_column :locations, :search_name

    add_column :observations, :lat, :decimal, precision: 15, scale: 10
    add_column :observations, :long, :decimal, precision: 15, scale: 10
  end

  def self.down
    remove_column :observations, :long
    remove_column :observations, :lat

    add_column :locations, :search_name, :string, limit: 200

    remove_column :locations_versions, :notes
    remove_column :locations, :notes

    remove_column :users, :location_format
    add_column :locations, :display_name, :string, limit: 200
    Location.connection.update %(
      UPDATE locations SET display_name = name
    )
    remove_column :locations, :name
    add_column :locations_versions, :display_name, :string, limit: 200
    Location.connection.update %(
      UPDATE locations_versions SET display_name = name
    )
    remove_column :locations_versions, :name
  end
end

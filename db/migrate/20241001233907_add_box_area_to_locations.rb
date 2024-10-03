class AddBoxAreaToLocations < ActiveRecord::Migration[7.1]
  require "extensions"

  def up
    add_column :locations, :box_area, :decimal, precision: 21, scale: 10
    add_column :location_versions, :box_area, :decimal, precision: 21, scale: 10
    add_column :locations, :center_lat, :decimal, precision: 15, scale: 10
    add_column :location_versions, :center_lat, :decimal, precision: 15,
               scale: 10
    add_column :locations, :center_lng, :decimal, precision: 15, scale: 10
    add_column :location_versions, :center_lng, :decimal, precision: 15,
               scale: 10
    add_column :observations, :location_lat, :decimal, precision: 15, scale: 10
    add_column :observations, :location_lng, :decimal, precision: 15, scale: 10
  end

  def down
    remove_column :observations, :location_lng
    remove_column :observations, :location_lat
    remove_column :location_versions, :center_lng
    remove_column :locations, :center_lng
    remove_column :location_versions, :center_lat
    remove_column :locations, :center_lat
    remove_column :location_versions, :box_area
    remove_column :locations, :box_area
  end
end

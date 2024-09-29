class AddBoxAreaToLocations < ActiveRecord::Migration[7.1]
  require "extensions"

  def up
    add_column :locations, :box_area, :decimal, precision: 21, scale: 10
    add_column :location_versions, :box_area, :decimal, precision: 21, scale: 10
  end

  def down
    remove_column :location_versions, :box_area
    remove_column :locations, :box_area
  end
end

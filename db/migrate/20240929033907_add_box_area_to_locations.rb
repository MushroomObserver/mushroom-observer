class AddBoxAreaToLocations < ActiveRecord::Migration[7.1]
  require "extensions"

  def up
    add_column :locations, :box_area, :decimal, precision: 21, scale: 10

    Location.all.each do |location|
      location.update!(box_area: location.box_area)
    end
  end

  def down
    remove_column :locations, :box_area
  end
end

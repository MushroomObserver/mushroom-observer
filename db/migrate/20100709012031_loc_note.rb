class LocNote < ActiveRecord::Migration
  # Adding locations.notes so there's a place for location change notes
  def self.up
    add_column :locations, :notes, :text
    add_column :locations_versions, :notes, :text
  end

  def self.down
    remove_column :locations_versions, :notes
    remove_column :locations, :notes
  end
end

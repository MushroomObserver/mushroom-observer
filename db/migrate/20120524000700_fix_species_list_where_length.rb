class FixSpeciesListWhereLength < ActiveRecord::Migration
  def self.up
    change_column :species_lists, :where, :string, :limit => 1024
  end

  def self.down
    change_column :species_lists, :where, :string, :limit => 100
  end
end

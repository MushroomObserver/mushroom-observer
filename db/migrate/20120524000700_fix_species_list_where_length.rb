class FixSpeciesListWhereLength < ActiveRecord::Migration[4.2]
  def self.up
    change_column :species_lists, :where, :string, limit: 1024
  end

  def self.down
    change_column :species_lists, :where, :string, limit: 100
  end
end

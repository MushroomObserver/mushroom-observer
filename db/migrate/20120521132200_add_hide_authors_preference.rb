class AddHideAuthorsPreference < ActiveRecord::Migration[4.2]
  def self.up
    add_column :users, :hide_authors, :enum, default: :none, null: false, limit: [:none, :above_species]
  end

  def self.down
    remove_column :users, :hide_authors
  end
end

class AddPrimaryKeyToProjectsSpeciesLists < ActiveRecord::Migration[6.1]
  def change
    rename_table("projects_species_lists", "project_species_lists")
    add_column(:project_species_lists, :id, :primary_key)
  end
end

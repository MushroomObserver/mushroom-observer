class AssociationOfProjectsAndObservationsImagesAndSpeciesLists < ActiveRecord::Migration[4.2]
  def self.up
    create_table :images_projects do |t|
      t.column "image_id",   :integer, null: false
      t.column "project_id", :integer, null: false
    end
    create_table :observations_projects do |t|
      t.column "observation_id", :integer, null: false
      t.column "project_id",     :integer, null: false
    end
    create_table :projects_species_lists do |t|
      t.column "project_id",      :integer, null: false
      t.column "species_list_id", :integer, null: false
    end
  end

  def self.down
    drop_table :images_projects
    drop_table :observations_projects
    drop_table :projects_species_lists
  end
end

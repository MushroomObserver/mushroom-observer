class FixProjectAssociationTables < ActiveRecord::Migration[4.2]
  def self.up
    drop_table :images_projects
    drop_table :observations_projects
    drop_table :projects_species_lists
    create_table :images_projects, id: false, force: true do |t|
      t.column "image_id",   :integer, null: false
      t.column "project_id", :integer, null: false
    end
    create_table :observations_projects, id: false, force: true do |t|
      t.column "observation_id", :integer, null: false
      t.column "project_id",     :integer, null: false
    end
    create_table :projects_species_lists, id: false, force: true do |t|
      t.column "project_id",      :integer, null: false
      t.column "species_list_id", :integer, null: false
    end
  end

  def self.down
  end
end

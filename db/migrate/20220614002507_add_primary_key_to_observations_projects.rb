class AddPrimaryKeyToObservationsProjects < ActiveRecord::Migration[6.1]
  def change
    rename_table("observations_projects", "project_observations")
    add_column(:project_observations, :id, :primary_key)
  end
end

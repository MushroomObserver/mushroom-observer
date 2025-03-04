class RemoveAcceptingObservationsFromProjects < ActiveRecord::Migration[7.0]
  def change
    remove_column :projects, :accepting_observations, :boolean
  end
end

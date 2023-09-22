class RemoveAcceptingObservationsFromProjects < ActiveRecord::Migration[6.1]
  def change
    remove_column :projects, :accepting_observations, :boolean
  end
end

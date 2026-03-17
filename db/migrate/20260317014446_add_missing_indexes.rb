class AddMissingIndexes < ActiveRecord::Migration[7.2]
  def change
    add_index(:project_observations, :project_id, if_not_exists: true)
    add_index(:project_observations, :observation_id, if_not_exists: true)
    add_index(:observations, :name_id, if_not_exists: true)
    add_index(:observations, :location_id, if_not_exists: true)
  end
end

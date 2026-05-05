# frozen_string_literal: true

class CreateProjectExcludedObservations < ActiveRecord::Migration[7.2]
  def change
    create_table(:project_excluded_observations) do |t|
      t.integer(:observation_id, null: false)
      t.integer(:project_id, null: false)
    end

    add_index(:project_excluded_observations, :observation_id,
              name: "index_project_excluded_observations_on_observation_id")
    add_index(:project_excluded_observations, :project_id,
              name: "index_project_excluded_observations_on_project_id")
    add_index(:project_excluded_observations, [:project_id, :observation_id],
              unique: true,
              name: "index_project_excluded_observations_on_project_and_obs")
  end
end

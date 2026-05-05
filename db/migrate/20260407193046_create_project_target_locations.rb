# frozen_string_literal: true

class CreateProjectTargetLocations < ActiveRecord::Migration[7.2]
  def change
    create_table(:project_target_locations) do |t|
      t.integer(:project_id, null: false)
      t.integer(:location_id, null: false)
    end

    add_index(:project_target_locations, :project_id)
    add_index(:project_target_locations, :location_id)
    add_index(:project_target_locations, [:project_id, :location_id],
              unique: true)
  end
end

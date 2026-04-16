# frozen_string_literal: true

class CreateProjectTargetNames < ActiveRecord::Migration[7.2]
  def change
    create_table(:project_target_names) do |t|
      t.integer(:project_id, null: false)
      t.integer(:name_id, null: false)
    end

    add_index(:project_target_names, :project_id)
    add_index(:project_target_names, :name_id)
    add_index(:project_target_names, [:project_id, :name_id], unique: true)
  end
end

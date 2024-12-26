# frozen_string_literal: true

class CreateProjectAliases < ActiveRecord::Migration[7.1]
  def change
    create_table(:project_aliases) do |t|
      t.integer(:project_id, null: false)
      t.integer(:target_id, null: false)
      t.string(:target_type, null: false)
      t.string(:name)

      t.timestamps

      t.foreign_key(:projects)
      t.index([:target_type, :target_id])
      t.index(:project_id)
    end
  end
end

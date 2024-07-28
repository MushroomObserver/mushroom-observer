# frozen_string_literal: true

class CreateFieldSlips < ActiveRecord::Migration[7.1]
  def change
    create_table(:field_slips) do |t|
      t.integer(:observation_id)
      t.integer(:project_id)
      t.string(:code, null: false)

      t.timestamps
    end
    add_index(:field_slips, :code, unique: true)
  end
end

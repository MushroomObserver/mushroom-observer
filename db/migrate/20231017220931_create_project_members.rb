# frozen_string_literal: true

class CreateProjectMembers < ActiveRecord::Migration[6.1]
  def change
    create_table(:project_members) do |t|
      t.integer(:project_id, foreign_key: true)
      t.integer(:user_id, foreign_key: true)
      t.boolean(:admin, default: false, null: false)
      t.boolean(:trusted, default: false, null: false)

      t.timestamps
    end
  end
end

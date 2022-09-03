# frozen_string_literal: true

class CreateVisualGroups < ActiveRecord::Migration[6.1]
  def change
    create_table(:visual_groups) do |t|
      t.string(:name, null: false)
      t.boolean(:reviewed, default: false, null: false)

      t.timestamps
    end
  end
end

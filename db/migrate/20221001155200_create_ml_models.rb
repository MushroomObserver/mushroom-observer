# frozen_string_literal: true

class CreateMlModels < ActiveRecord::Migration[6.1]
  def change
    create_table(:visual_models) do |t|
      t.string(:name, null: false)

      t.timestamps
    end

    create_table(:visual_groups) do |t|
      t.integer(:visual_model_id)
      t.string(:name, null: false)
      t.boolean(:approved, default: false, null: false)
      t.text(:description)

      t.timestamps
    end

    create_table(:visual_group_images) do |t|
      t.integer(:image_id)
      t.integer(:visual_group_id)
      t.boolean(:included, default: true, null: false)
    end
  end
end

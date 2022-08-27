class CreateVisualGroups < ActiveRecord::Migration[6.1]
  def change
    create_table :visual_groups do |t|
      t.integer :group_name_id # , null: false
      t.boolean :reviewed, default: false, null: false

      t.timestamps
    end
  end
end

class CreateVisualGroups < ActiveRecord::Migration[6.1]
  def change
    create_table :visual_groups do |t|
      t.integer :name_id
      t.boolean :reviewed

      t.timestamps
    end
  end
end

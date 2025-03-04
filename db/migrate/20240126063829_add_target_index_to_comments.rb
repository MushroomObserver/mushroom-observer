class AddTargetIndexToComments < ActiveRecord::Migration[7.1]
  def up
    add_index :comments, [:target_id, :target_type], name: :target_index
  end

  def down
    remove_index :comments, [:target_id, :target_type], name: :target_index
  end
end

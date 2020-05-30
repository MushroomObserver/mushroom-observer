class RemoveCreatedHere < ActiveRecord::Migration[4.2]
  def up
    remove_column :users, :created_here
  end

  def down
    add_column :users, :created_here, :boolean, default: true
  end
end

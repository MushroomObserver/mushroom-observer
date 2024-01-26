class AddNamingIndexToVotes < ActiveRecord::Migration[7.1]
  def up
    add_index :votes, :naming_id, name: :naming_index
  end

  def down
    remove_index :votes, :naming_id, name: :naming_index
  end
end

class AddObservationIndexToVotes < ActiveRecord::Migration[7.1]
  def up
    add_index :votes, :observation_id, name: :observation_index
  end

  def down
    remove_index :votes, :observation_id, name: :observation_index
  end
end

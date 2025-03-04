class RedoIndexesForObservationViews < ActiveRecord::Migration[7.1]
  def up
    remove_index :observation_views, [:observation_id, :user_id],
                 name: :user_observation_index
    add_index :observation_views, :observation_id, name: :observation_index
    add_index :observation_views, :user_id, name: :user_index
  end

  def down
    remove_index :observation_views, :observation_id, name: :observation_index
    remove_index :observation_views, :user_id, name: :user_index
    add_index :observation_views, [:observation_id, :user_id],
              name: :user_observation_index
  end
end

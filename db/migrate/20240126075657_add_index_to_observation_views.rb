class AddIndexToObservationViews < ActiveRecord::Migration[7.1]
  def up
    add_index :observation_views, [:observation_id, :user_id],
              name: :user_observation_index
  end

  def down
    remove_index :observation_views, [:observation_id, :user_id],
                 name: :user_observation_index
  end
end

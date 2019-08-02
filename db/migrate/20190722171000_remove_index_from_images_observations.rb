class RemoveIndexFromImagesObservations < ActiveRecord::Migration[4.2]
  def up
    remove_index :images_observations, :observation_id
  end

  def down
    add_index :images_observations, :observation_id
  end
end

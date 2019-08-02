class ReaddIndexToImagesObservations < ActiveRecord::Migration[4.2]
  def up
    add_index :images_observations, :observation_id
  end

  def down
    remove_index :images_observations, :observation_id
  end
end

class AddPrimaryKeyAndRankToImagesObservations < ActiveRecord::Migration[5.2]
  def change
    rename_table("images_observations", "observation_images")
    add_column(:observation_images, :id, :primary_key)
    add_column(:observation_images, :rank, :integer, default: 0, null: false)
  end
end

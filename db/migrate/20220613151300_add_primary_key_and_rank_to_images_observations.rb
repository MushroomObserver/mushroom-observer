class AddPrimaryKeyAndRankToImagesObservations < ActiveRecord::Migration[5.2]
  def change
    rename_table("images_observations", "image_observations")
    add_column(:image_observations, :id, :primary_key)
    add_column(:image_observations, :rank, :integer, default: 0, null: false)
  end
end

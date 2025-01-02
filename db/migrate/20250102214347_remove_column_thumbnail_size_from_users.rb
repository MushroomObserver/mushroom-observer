class RemoveColumnThumbnailSizeFromUsers < ActiveRecord::Migration[7.1]
  def change
    remove_column :users, :thumbnail_size, :integer
  end
end

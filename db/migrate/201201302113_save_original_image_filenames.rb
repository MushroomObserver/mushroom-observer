class SaveOriginalImageFilenames < ActiveRecord::Migration[4.2]
  def self.up
    add_column(:images, :original_name, :string, limit: 120, default: "")
  end

  def self.down
    remove_column(:images, :original_name)
  end
end

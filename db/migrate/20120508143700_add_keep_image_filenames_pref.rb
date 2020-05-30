class AddKeepImageFilenamesPref < ActiveRecord::Migration[4.2]
  def self.up
    add_column :users, :keep_filenames, :boolean, default: true, null: false
  end

  def self.down
    remove_column :users, :keep_filenames
  end
end

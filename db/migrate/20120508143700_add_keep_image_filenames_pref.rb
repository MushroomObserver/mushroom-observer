class AddKeepImageFilenamesPref < ActiveRecord::Migration
  def self.up
    add_column :users, :keep_filenames, :boolean, default: true, null: false
  end

  def self.down
    remove_column :users, :keep_filenames
  end
end

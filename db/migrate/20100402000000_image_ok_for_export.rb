class ImageOkForExport < ActiveRecord::Migration
  def self.up
    add_column :images, :ok_for_export, :boolean, :default => true, :null => false
  end

  def self.down
    remove_column :images, :ok_for_export
  end
end

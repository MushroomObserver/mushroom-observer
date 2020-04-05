# encoding: utf-8
class ImageOkForExport < ActiveRecord::Migration[4.2]
  def self.up
    add_column :images, :ok_for_export, :boolean, default: true, null: false
  end

  def self.down
    remove_column :images, :ok_for_export
  end
end

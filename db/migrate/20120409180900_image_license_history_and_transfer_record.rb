class ImageLicenseHistoryAndTransferRecord < ActiveRecord::Migration
  def self.up
    add_column :images, :license_history, :string, :null => true, :default => nil
    add_column :images, :transferred, :boolean, :null => false, :default => false
    Image.connection.update 'UPDATE images SET transferred = TRUE;'
  end

  def self.down
    add_column :images, :license_history
    add_column :images, :transferred
  end
end


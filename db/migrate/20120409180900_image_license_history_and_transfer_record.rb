class ImageLicenseHistoryAndTransferRecord < ActiveRecord::Migration[4.2]
  def self.up
    add_column :images, :transferred, :boolean, null: false, default: false
    Image.connection.update "UPDATE images SET transferred = TRUE;"

    create_table :copyright_changes, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8", force: true do |t|
      t.column "user_id",      :integer,  null: false
      t.column "modified",     :datetime, null: false
      t.column "target_type",  :string,   null: false, limit: 30
      t.column "target_id",    :integer,  null: false
      t.column "year",         :integer
      t.column "name",         :string
      t.column "license_id",   :integer
    end
  end

  def self.down
    remove_column :images, :transferred
    drop_table :copyright_changes
  end
end

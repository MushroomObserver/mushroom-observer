class AddGpsStrippedColumn < ActiveRecord::Migration[4.2]
  def up
    add_column :images, :gps_stripped, :boolean, default: false, null: false
  end

  def down
    remove_column :images, :gps_stripped
  end
end

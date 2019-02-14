class AddHiddenColumn < ActiveRecord::Migration[4.2]
  def up
    add_column :observations, :gps_hidden, :boolean, default: false, null: false
  end

  def down
    remove_column :observations, :gps_hidden
  end
end

class AddColumnsToDonation < ActiveRecord::Migration
  def change
    add_column :donations, :recurring, :boolean, default: false
  end
end

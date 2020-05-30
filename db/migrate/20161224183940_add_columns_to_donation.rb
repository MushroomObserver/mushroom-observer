class AddColumnsToDonation < ActiveRecord::Migration[4.2]
  def change
    add_column :donations, :recurring, :boolean, default: false
  end
end

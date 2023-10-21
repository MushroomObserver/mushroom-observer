class RemoveFlavorFromNotifications < ActiveRecord::Migration[6.1]
  def change
    remove_column :notifications, :flavor, :integer
  end
end

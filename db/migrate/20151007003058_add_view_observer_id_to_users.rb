class AddViewObserverIdToUsers < ActiveRecord::Migration[4.2]
  def change
    add_column :users, :view_owner_id, :boolean, default: false, null: false
  end
end

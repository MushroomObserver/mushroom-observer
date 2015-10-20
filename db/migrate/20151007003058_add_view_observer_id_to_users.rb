class AddViewObserverIdToUsers < ActiveRecord::Migration
  def change
    add_column :users, :view_owner_id, :boolean, default: false, null: false
  end
end

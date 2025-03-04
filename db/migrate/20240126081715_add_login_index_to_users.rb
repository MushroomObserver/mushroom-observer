class AddLoginIndexToUsers < ActiveRecord::Migration[7.1]
  def up
    add_index :users, :login, name: :login_index, if_not_exists: true
  end

  def down
    remove_index :users, :login_id, name: :login_index
  end
end

class AddInatUsernameToUsers < ActiveRecord::Migration[7.1]
  def change
    add_column :users, :inat_username, :string
  end
end

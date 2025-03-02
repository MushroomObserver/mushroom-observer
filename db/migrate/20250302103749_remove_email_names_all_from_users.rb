class RemoveEmailNamesAllFromUsers < ActiveRecord::Migration[7.2]
  def change
    remove_column :users, :email_names_all, :boolean
  end
end

class RemoveEmailAllFromUser < ActiveRecord::Migration[7.2]
  def change
    remove_column :users, :email_comments_all, :boolean
    remove_column :users, :email_locations_all, :boolean
    remove_column :users, :email_names_all, :boolean
    remove_column :users, :email_observations_all, :boolean
  end
end

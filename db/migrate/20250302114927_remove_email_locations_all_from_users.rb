class RemoveEmailLocationsAllFromUsers < ActiveRecord::Migration[7.2]
  def change
    remove_column :users, :email_locations_all, :boolean
  end
end

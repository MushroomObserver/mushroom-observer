class UpdatePreferredLicenses < ActiveRecord::Migration[7.1]
  def change
    change_column_default(:images, :license_id, from: 1, to: 10)
    change_column_default(:users, :license_id, from: 3, to: 10)
  end
end

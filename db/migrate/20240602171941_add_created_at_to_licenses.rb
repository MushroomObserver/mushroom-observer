class AddCreatedAtToLicenses < ActiveRecord::Migration[7.1]
  def change
    add_column :licenses, :created_at, :datetime, precision: nil
  end
end

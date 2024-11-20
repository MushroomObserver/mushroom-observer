class AddOriginalImageQuotaToUsers < ActiveRecord::Migration[7.1]
  def change
    add_column(:users, :original_image_quota, :integer, default: 0)
  end
end

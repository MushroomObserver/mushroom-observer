class ResetUserImageSizeValues < ActiveRecord::Migration[6.1]
  def change
    change_column_default :users, :image_size, 5
    User.update_all(image_size: "huge")
  end
end

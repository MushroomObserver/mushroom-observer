class ResetUserImageSizeValues < ActiveRecord::Migration[6.1]
  def change
    User.update_all(image_size: "huge")
  end
end

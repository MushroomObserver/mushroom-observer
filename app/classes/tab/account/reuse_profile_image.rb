# frozen_string_literal: true

# "Reuse an existing image as your profile picture" link, on the
# account profile edit form.
class Tab::Account::ReuseProfileImage < Tab::Base
  def initialize(user:)
    super()
    @user = user
  end

  def title
    :profile_image_reuse.t
  end

  def path
    images_reuse_path(target_type: "User", target_id: @user.id)
  end

  def html_options
    { icon: :reuse }
  end

  def model
    @user
  end
end

# frozen_string_literal: true

# Clicking on an image currently fires a GET to these actions... because it
# comes from a link made by Components::InteractiveImage(image_link: url_args)
# with CRUD refactor, change component link to fire a POST somehow?

# No need to remove_images from Account profile: reuse_image removes image
module Account::Profile
  class ImagesController < ApplicationController
    before_action :login_required

    # PUT action. Does not require a param, just removes user.image_id
    def detach
      if @user&.image
        @user.update(image: nil)
        flash_notice(:runtime_profile_removed_image.t)
      end
      redirect_to(edit_account_profile_path)
    end
  end
end

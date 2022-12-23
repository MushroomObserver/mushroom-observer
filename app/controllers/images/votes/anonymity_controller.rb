# frozen_string_literal: true

# NOTE: These two are more properly account preferences actions
# Move to Images::Votes::AnonymityController#edit and update
# Move test from images_controller_test
#
module Images::Votes
  class AnonymityController < ApplicationController
    before_action :login_required

    # Bulk update anonymity of user's image votes.
    # Input: params[:commit] - which button user pressed
    # Outputs:
    #   @num_anonymous - number of existing anonymous votes
    #   @num_public    - number of existing puclic votes

    # bulk_vote_anonymity_updater
    def edit
      @num_anonymous = ImageVote.where(user_id: @user.id).
                       where(anonymous: true).
                       pluck(ImageVote[:id].count.as("total"))&.first
      @num_public = ImageVote.where(user_id: @user.id).
                    where(anonymous: false).
                    pluck(ImageVote[:id].count.as("total"))&.first
    end

    def update
      submit = params[:commit]
      if submit == :image_vote_anonymity_make_anonymous.l
        ImageVote.where(user_id: @user.id).update_all(anonymous: true)
        flash_notice(:image_vote_anonymity_made_anonymous.t)
      elsif submit == :image_vote_anonymity_make_public.l
        ImageVote.where(user_id: @user.id).update_all(anonymous: false)
        flash_notice(:image_vote_anonymity_made_public.t)
      else
        flash_error(
          :image_vote_anonymity_invalid_submit_button.l(label: submit)
        )
      end
      redirect_to(edit_account_preferences_path)
    end
  end
end

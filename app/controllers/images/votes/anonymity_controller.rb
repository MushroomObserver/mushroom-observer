# frozen_string_literal: true

module Images::Votes
  class AnonymityController < ApplicationController
    before_action :login_required

    # NOTE: These two are more properly account preferences actions
    # Move to Account::Preferences::ImageVotes#edit and update
    # Move test from images_controller_test
    #
    # Bulk update anonymity of user's image votes.
    # Input: params[:commit] - which button user pressed
    # Outputs:
    #   @num_anonymous - number of existing anonymous votes
    #   @num_public    - number of existing puclic votes
    def bulk_vote_anonymity_updater
      if request.method == "POST"
        create_anonymity_change
      else
        @num_anonymous = ImageVote.where(user_id: @user.id).
                         where(anonymous: true).
                         pluck(ImageVote[:id].count.as("total"))&.first
        @num_public = ImageVote.where(user_id: @user.id).
                      where(anonymous: false).
                      pluck(ImageVote[:id].count.as("total"))&.first
      end
    end

    private

    def create_anonymity_change
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

    public

    # Linked from account/preferences/_privacy
    # Move to new controller Account::Preferences::ImagesController#update
    # Move test from images_controller_test
    def bulk_filename_purge
      Image.where(user_id: User.current_id).update_all(original_name: "")
      flash_notice(:prefs_bulk_filename_purge_success.t)
      redirect_to(edit_account_preferences_path)
    end
  end
end

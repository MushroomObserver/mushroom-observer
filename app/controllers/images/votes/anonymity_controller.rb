# frozen_string_literal: true

module Images::Votes
  class AnonymityController < ApplicationController
    before_action :login_required

    # Bulk update anonymity of user's image votes.
    # Input: params[:commit] - which button user pressed
    # Outputs:
    #   @num_anonymous - number of existing anonymous votes
    #   @num_public    - number of existing puclic votes
    def bulk_vote_anonymity_updater
      if request.method == "POST"
        submit = params[:commit]
        if submit == :image_vote_anonymity_make_anonymous.l
          ImageVote.connection.update(%(
          UPDATE image_votes SET anonymous = TRUE WHERE user_id = #{@user.id}
        ))
          flash_notice(:image_vote_anonymity_made_anonymous.t)
        elsif submit == :image_vote_anonymity_make_public.l
          ImageVote.connection.update(%(
          UPDATE image_votes SET anonymous = FALSE WHERE user_id = #{@user.id}
        ))
          flash_notice(:image_vote_anonymity_made_public.t)
        else
          flash_error(
            :image_vote_anonymity_invalid_submit_button.l(label: submit)
          )
        end
        redirect_to(edit_account_preferences_path)
      else
        @num_anonymous = ImageVote.connection.select_value(%(
        SELECT count(id) FROM image_votes
        WHERE user_id = #{@user.id} AND anonymous
      ))
        @num_public = ImageVote.connection.select_value(%(
        SELECT count(id) FROM image_votes
        WHERE user_id = #{@user.id} AND !anonymous
      ))
      end
    end
  end
end

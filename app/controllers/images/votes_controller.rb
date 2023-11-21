# frozen_string_literal: true

module Images
  class VotesController < ApplicationController
    before_action :login_required

    def update
      @id = params[:image_id]
      @image = find_or_goto_index(Image, @id)
      return unless @image

      value = params[:value]
      raise("Bad value.") if value != "0" && !Image.validate_vote(value)

      @value = value == "0" ? nil : Image.validate_vote(value)
      anon = (@user.votes_anonymous == "yes")
      @image.change_vote(@user, @value, anon: anon)

      respond_to do |format|
        # Change user's vote (on anyone's image) and go to next image.
        format.html do
          if params[:next]
            redirect_to_next_object(:next, Image, @id)
          else
            redirect_with_query(image_path(id: @id))
          end
        end
        format.turbo_stream do
          render(partial: "images/votes/update")
        end
      end
    end
  end
end

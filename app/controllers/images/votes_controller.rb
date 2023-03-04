# frozen_string_literal: true

module Images
  class VotesController < ApplicationController
    before_action :login_required

    # Change user's vote (on anyone's image) and go to next image.
    # Images::VotesController#update
    # cast_vote
    def update
      image = find_or_goto_index(Image, params[:id].to_s)
      return unless image

      image.change_vote(@user, params[:value])

      respond_to do |format|
        format.html do
          if params[:next]
            redirect_to_next_object(:next, Image, params[:id].to_s)
          else
            redirect_with_query(image_path(id: params[:id]))
          end
        end
        format.js do
          @id = params[:id]
          @image = image
        end
      end
    end
  end
end

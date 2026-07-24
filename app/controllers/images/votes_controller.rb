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
            redirect_to(image_path(id: @id))
          end
        end
        format.turbo_stream do
          render(turbo_stream: vote_interface_streams)
        end
      end
    end

    private

    # Was `render(partial: "images/votes/update")`, the partial just
    # emitted a single `turbo_stream.update("image_vote_#{id}")`
    # wrapping `Components::ImageFragment::VoteInterface` — inlined
    # here. Two targets, not one: the lightbox caption's copy
    # (`context: :lightbox`) lives under a `lightbox_`-prefixed id
    # (see `VoteInterface#vote_html_id`) inside the hidden caption
    # element that's always in the DOM now (#4894), so this update
    # reaches it whether the lightbox is open or closed.
    #
    # `replace`, not `update` -- `VoteInterface`'s own render output
    # IS the full `<div id="...">` wrapper, so `update` (which swaps
    # inner content only) would nest a duplicate-id div inside the
    # original instead of swapping it.
    def vote_interface_streams
      [
        turbo_stream.replace("image_vote_#{@image.id}",
                             vote_interface),
        turbo_stream.replace("lightbox_image_vote_#{@image.id}",
                             vote_interface(context: :lightbox))
      ]
    end

    def vote_interface(context: :overlay)
      ::Components::ImageFragment.new(
        type: :vote_interface,
        user: @user, image: @image, votes: true, context: context
      )
    end
  end
end

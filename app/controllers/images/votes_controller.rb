# frozen_string_literal: true

module Images
  class VotesController < ApplicationController
    before_action :login_required
    skip_before_action :login_required, only: [:show]

    # Renders just the vote interface for one image, fresh and
    # uncached -- meant to be fetched via a lazy Turbo Frame so a
    # viewer's own vote state never gets baked into `Matrix::Box`'s
    # shared fragment cache (#4895). Anonymous viewers can load this
    # too (`.require-user` CSS-hides it), matching the overlay copy's
    # existing render-regardless-of-`@user` behavior.
    #
    # Deliberately not `find_or_goto_index` -- that flashes an error
    # and redirects to the model's index, which is right for a normal
    # page load but wrong for a frame-only fetch: the frame would try
    # to swap in a full index page's markup (or just break), and the
    # flash would linger to surprise the user on their next real
    # navigation. A plain 404 leaves the frame empty and leaks nothing.
    def show
      @image = Image.find_by(id: params[:image_id])
      return head(:not_found) unless @image

      @context = params[:context]&.to_sym || :overlay
      render(Views::Controllers::Images::Votes::Show.new(
               image: @image, user: @user, context: @context
             ), layout: false)
    end

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
    #
    # The target may currently be the lazy `<turbo-frame>` (#4895) --
    # its content hasn't loaded, or has loaded and the div underneath
    # shares the same id (Turbo's own `getElementById`-based lookup
    # returns whichever is first in document order, i.e. the frame,
    # its ancestor). Either way `replace` swaps the frame for a plain
    # `VoteInterface` div, same id -- correct: once voted, that
    # instance has fresh, correct data and no longer needs to be
    # lazily reloadable.
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

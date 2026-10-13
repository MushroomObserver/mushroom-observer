# frozen_string_literal: true

module Images
  class VotesController < ApplicationController
    before_action :login_required
    skip_before_action :login_required, only: [:show]

    # Renders just the vote interface for one image, fresh and
    # uncached -- fetched via a lazy Turbo Frame so a viewer's vote
    # state stays out of `Matrix::Box`'s shared fragment cache.
    # Anonymous viewers can load this too (`.require-user` CSS-hides
    # it), matching the overlay copy's render-regardless-of-`@user`
    # behavior.
    #
    # Not `find_or_goto_index`: that flashes and redirects to the
    # index, wrong for a frame-only fetch -- the frame would try to
    # swap in a full index page. A plain 404 leaves the frame empty.
    def show
      @image = Image.find_by(id: params[:image_id])
      return head(:not_found) unless @image

      @context = normalized_context
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
      @context = normalized_context

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

    # Two targets: the lightbox caption's copy (`context: :lightbox`)
    # lives under a `lightbox_`-prefixed id, always in the DOM, so
    # this reaches it whether the lightbox is open or closed.
    #
    # `replace`, not `update`: `VoteInterface`'s render output IS the
    # full `<div id="...">` wrapper, so `update` would nest a
    # duplicate-id div instead of swapping it. Also swaps out the
    # lazy `<turbo-frame>` target if it hasn't loaded yet.
    def vote_interface_streams
      [
        turbo_stream.replace("image_vote_#{@image.id}",
                             vote_interface(context: @context)),
        turbo_stream.replace("lightbox_image_vote_#{@image.id}",
                             vote_interface(context: :lightbox))
      ]
    end

    def vote_interface(context: :matrix)
      ::Components::ImageFragment.new(
        type: :vote_interface,
        user: @user, image: @image, votes: true, context: context
      )
    end

    # `:overlay` was VoteInterface's context name before it was
    # renamed to `:matrix` -- mapped here so an old cached
    # LazyVoteInterface turbo-frame (whose src= URL still has
    # `context=overlay` baked in) doesn't 404 or fall into the
    # unstyled `vote-section-inline` branch.
    def normalized_context
      value = params[:context]&.to_sym
      value == :overlay ? :matrix : (value || :matrix)
    end
  end
end

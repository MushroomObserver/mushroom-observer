# frozen_string_literal: true

module Views::Controllers::Images
  module Votes
    # Turbo Frame response for `Images::VotesController#show` -- the
    # frame's own id must match `VoteInterface.frame_id` so Turbo can
    # find and swap it out of this response (see #4895; fetched lazily
    # from `Image::Base#render_image_vote_section` /
    # `ImageFragment::LightboxCaption#render_vote_section` instead of
    # rendering inline inside `Matrix::Box`'s cached HTML).
    class Show < Views::Base
      prop :image, ::Image
      prop :user, _Nilable(::User)
      prop :context, Symbol, default: :overlay

      def view_template
        turbo_frame_tag(frame_id) do
          ImageFragment(type: :vote_interface, user: @user, image: @image,
                        votes: true, context: @context)
        end
      end

      private

      def frame_id
        Components::ImageFragment::VoteInterface.frame_id(
          image_id: @image.id, context: @context
        )
      end
    end
  end
end

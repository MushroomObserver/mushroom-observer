# frozen_string_literal: true

# Inline `<turbo-stream>` backfill for a page of lazy vote-interface
# frames. Turbo executes stream elements wherever they appear in the
# document, so one replace per image/context rendered after a matrix
# grid fills every frame in the same response — no per-frame `src`
# fetch ever fires. Must render outside any fragment cache: the
# content is viewer-specific (`Image#users_vote`), which is why the
# cached boxes hold only empty frames (see `LazyVoteInterface`).
#
# A stream whose target frame isn't in the document (an image rendered
# with `votes: false`, or a duplicate thumb) is a silent no-op.
class Components::ImageFragment::VoteInterfaceStreams < Components::Base
  register_element :turbo_stream

  prop :images, _Array(::Image)
  prop :user, _Nilable(::User), default: nil

  def view_template
    images = @images.uniq
    return if images.empty?

    preload_votes(images)
    images.each do |image|
      stream_for(image, :overlay)
      stream_for(image, :lightbox)
    end
  end

  private

  # One query for the whole page — `Image#vote_hash` walks the
  # `image_votes` association per image.
  def preload_votes(images)
    ActiveRecord::Associations::Preloader.new(
      records: images, associations: :image_votes
    ).call
  end

  def stream_for(image, context)
    turbo_stream(
      action: "replace",
      target: Components::ImageFragment::VoteInterface.frame_id(
        image_id: image.id, context: context
      )
    ) do
      template do
        ImageFragment(type: :vote_interface, user: @user, image: image,
                      votes: true, context: context)
      end
    end
  end
end

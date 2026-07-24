# frozen_string_literal: true

# A lazy-loading Turbo Frame wrapper around `VoteInterface`, meant to
# be called from inside cacheable render paths (`Matrix::Box ->
# InteractiveImage`/`LightboxCaption`) instead of `VoteInterface`
# itself. `Matrix::Box`'s fragment cache key has no user component
# (`Components::Matrix::Table.cache_key_for`) -- rendering
# `VoteInterface` directly would bake whichever viewer's request
# happened to write the cache entry's vote state into the shared HTML
# for every subsequent viewer. `loading: "lazy"` defers the fetch
# until the frame actually scrolls into view, so an index page with
# many matrix boxes doesn't fire a request per box on load. See #4895.
#
# @example
#   ImageFragment(type: :lazy_vote_interface, image: @image, context: :overlay)
class Components::ImageFragment::LazyVoteInterface < Components::Base
  prop :image, ::Image
  prop :context, Symbol, default: :overlay

  def view_template
    turbo_frame_tag(
      Components::ImageFragment::VoteInterface.frame_id(
        image_id: @image.id, context: @context
      ),
      src: image_vote_interface_path(image_id: @image.id, context: @context),
      loading: "lazy"
    )
  end
end

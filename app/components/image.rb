# frozen_string_literal: true

# Top-level hand-off to `Components::Image::Interactive`, purely so
# callers get Kit syntax (`Image(...)`) instead of the verbose
# `render(Components::Image::Interactive.new(...))`. Not a dispatcher --
# `Image::Interactive` is the only thing under `Components::Image` that
# genuinely renders "an image"; the other `Components::Image::Base`
# subclasses (`Form::UploadGallery::Item`, `Carousel::Item`,
# `ImageGallery::Thumbnail`) are differently-shaped UI fragments (an
# editable form row, a carousel-slide fragment, a bare thumbnail) built
# for their own specific contexts, not swappable variants of one
# concept, so they don't belong behind a `type:` selector here.
#
# `self.new` returns the `Interactive` instance directly (matching the
# `Button`/`Link`/`Help`/`Modal` dispatcher pattern) rather than
# wrapping it in another `render` call, so there's no double-render.
#
# @example
#   Image(user: @user, image: @image, size: :thumbnail, votes: true)
class Components::Image < Components::Base
  def self.new(**, &block)
    Components::Image::Interactive.new(**, &block)
  end
end

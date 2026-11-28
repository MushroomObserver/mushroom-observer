# frozen_string_literal: true

# An image's original filename, shown only when `attempt:` is true
# and the viewer has permission to see it, or the owner's
# `keep_filenames` preference is "keep_and_show" -- otherwise renders
# empty. Filename text only, no id badge -- a caller that wants one
# alongside it (e.g. in a flex-justified row) renders
# `Badge(type: :id, object: image, size: ...)` directly.
#
# Factored out so the same permission-gated filename logic is shared
# by `Image::Base#render_original_filename` (InteractiveImage's inline
# placement), `Grid::Box` (the images index panel body, which already
# shows this image's id in its title row -- no second badge needed),
# and the image-reuse index (its panel body, paired with a badge).
class Components::Image::OriginalFilenameRow < Components::Base
  prop :image, ::Image
  prop :attempt, _Boolean, default: true

  def view_template
    span { @image.original_name if show_original_name? }
  end

  private

  def show_original_name?
    return false unless @attempt && @image.original_name.present?

    permission?(@image) ||
      (@image.user && @image.user.keep_filenames == "keep_and_show")
  end
end

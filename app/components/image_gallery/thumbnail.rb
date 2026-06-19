# frozen_string_literal: true

# Inner content of a single thumbnail indicator. The outer
# `<li class="carousel-indicator …">` wrapper (with its `data-target` /
# `data-slide-to` / extra `data-*` attributes) is owned by the
# `Components::Carousel` primitive (via `c.thumb(...) { render(this) }`);
# this component just emits the small `<img>` that goes inside.
#
# Used by `Components::ImageGallery#render_carousel` and reused by
# `Components::Form::UploadGallery` for its thumbnail strip.
#
# @example
#   render Components::ImageGallery::Thumbnail.new(
#     user: @user,
#     image: @image
#   )
class Components::ImageGallery::Thumbnail < Components::Image::Base
  def initialize(**props)
    props[:size] ||= :thumbnail
    props[:fit] ||= :contain
    base_classes = "carousel-thumbnail"
    base_classes += " set-src" if props[:upload]
    props[:extra_classes] =
      [props[:extra_classes], base_classes].compact.join(" ")
    super
  end

  def view_template
    @img_instance, @img_id = extract_image_and_id
    @img_id ||= "img_id_missing"
    @img_id = @img_id.id if @img_id.is_a?(::Image)
    @data = build_render_data(@img_instance, @img_id)

    img(
      src: @data[:img_src],
      alt: @notes,
      class: @data[:img_class],
      data: @data[:img_data]
    )
  end
end

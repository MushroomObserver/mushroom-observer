# frozen_string_literal: true

# Draw an interactive image with all the fixin's.
#
# This Phlex component renders an interactive image with lazy loading,
# lightbox support, voting, and other features. It inherits shared
# functionality from BaseImage.
#
# @example
#   render Components::InteractiveImage.new(
#     user: current_user,
#     image: @image,
#     size: :thumbnail,
#     votes: true
#   )
class Components::InteractiveImage < Components::BaseImage
  # Override :image prop to only accept Image instances (not Integer IDs).
  # InteractiveImage is for displaying existing, persisted images.
  # Form components like Form::ImageCarouselItem inherit from BaseImage instead,
  # which accepts Integer IDs for newly uploaded images with provisional IDs.
  prop :image, _Nilable(::Image)

  def view_template
    return if @upload && @image.blank?

    # Get image instance and ID
    img_instance, img_id = extract_image_and_id

    # Build render data
    render_data = build_render_data(img_instance, img_id)

    # Render the interactive image
    render_interactive_image(img_instance, img_id, render_data)
  end

  private

  def render_interactive_image(img_instance, img_id, data)
    div(
      id: data[:html_id],
      class: "image-sizer position-relative mx-auto",
      style: build_width_style(data[:width])
    ) do
      render_image_container(img_id, data)
      render_stretched_link(data[:image_link])
      render_image_overlays(img_instance, data)
    end

    render_original_filename(img_instance)
  end

  def build_width_style(width)
    width.present? ? "width: #{width}px;" : ""
  end

  def render_image_container(img_id, data)
    div(
      class: "image-lazy-sizer overflow-hidden",
      style: "padding-bottom: #{data[:proportion]}%;"
    ) do
      render_lazy_image(img_id, data)
      render_noscript_image(img_id, data)
    end
  end

  def render_lazy_image(img_id, data)
    img(
      src: image_path("placeholder.svg"),
      alt: @notes,
      class: "#{data[:img_class]} lazy image_#{img_id}",
      data: data[:img_data]
    )
  end

  def render_noscript_image(img_id, data)
    noscript do
      img(
        src: data[:img_src],
        alt: @notes,
        class: "#{data[:img_class]} img-noscript image_#{img_id}"
      )
    end
  end

  def render_image_overlays(img_instance, data)
    render_lightbox_link(data[:lightbox_data]) if data[:lightbox_data]
    render_image_vote_section(img_instance)
  end
end

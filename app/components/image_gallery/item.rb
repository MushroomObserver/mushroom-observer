# frozen_string_literal: true

# Inner content of a single read-only image-gallery slide. The outer
# `<div class="item …">` wrapper is owned by the `Components::Carousel`
# primitive (via `c.item(...) { render(this) }`); this component emits
# the image + overlays + caption that go inside.
#
# Used by `Components::ImageGallery#render_carousel`.
#
# @example
#   render Components::ImageGallery::Item.new(
#     user: @user,
#     image: @image,
#     object: @observation
#   )
class Components::ImageGallery::Item < Components::Image::Base
  prop :object, _Nilable(::AbstractModel), default: nil

  def initialize(object: nil, **props)
    props[:size] ||= :large
    props[:fit] ||= :contain
    props[:original] ||= true
    props[:extra_classes] ||= "carousel-image"
    super
  end

  def view_template
    @img_instance, @img_id = extract_image_and_id
    @data = build_render_data(@img_instance, @img_id)

    render_carousel_image
    render_carousel_overlays
    render_carousel_caption
  end

  private

  def render_carousel_image
    img(
      src: @data[:img_src],
      alt: @notes,
      class: @data[:img_class],
      data: @data[:img_data]
    )
  end

  def render_carousel_overlays
    render_stretched_link if @user && @data[:image_link]
    render_lightbox_link if @data[:lightbox_data]
  end

  def render_carousel_caption
    div(class: "carousel-caption") do
      render_image_vote_section
      if image_info_html.present?
        div(class: "image-info d-none d-sm-block") { image_info_html }
      end
    end
  end

  def image_info_html
    return "" unless @img_instance && @object

    [
      owner_original_name,
      copyright,
      notes
    ].compact_blank.safe_join
  end

  def copyright
    return "" unless @img_instance

    render(Components::Image::Copyright.new(
             user: @user,
             image: @img_instance,
             object: @object
           ))
  end

  def owner_original_name
    return "" unless show_original_name? &&
                     (owner_name = @img_instance.original_name).present?

    div(class: "image-original-name") { owner_name }
  end

  def show_original_name?
    @original && @img_instance &&
      @img_instance.original_name.present? &&
      (permission?(@img_instance) ||
       @img_instance.user &&
       @img_instance.user.keep_filenames == "keep_and_show")
  end

  def notes
    return "" if @img_instance.notes.blank?

    div(class: "image-notes") { @img_instance.notes.tl.truncate_html(300) }
  end
end

# frozen_string_literal: true

# Individual carousel slide item component.
#
# Renders a single slide in a Bootstrap carousel with:
# - Large image with object-fit: contain
# - Stretched link overlay
# - Lightbox button
# - Carousel caption with votes and image info
#
# @example
#   render Components::CarouselItem.new(
#     user: @user,
#     image: @image,
#     object: @observation,
#     index: 0
#   )
class Components::CarouselItem < Components::BaseImage
  # Additional carousel-specific properties
  prop :index, Integer, default: 0
  prop :object, _Nilable(AbstractModel), default: nil

  def initialize(index: 0, object: nil, **props)
    # Set carousel-specific defaults
    props[:size] ||= :large
    props[:fit] ||= :contain
    props[:original] ||= true
    props[:extra_classes] ||= "carousel-image"

    super
  end

  def view_template
    # Get image instance and ID
    @img_instance, @img_id = extract_image_and_id

    # Build render data
    @data = build_render_data(@img_instance, @img_id)

    # Render the carousel item
    div(
      id: "carousel_item_#{@img_id}",
      class: build_item_classes
    ) do
      render_carousel_image
      render_carousel_overlays
      render_carousel_caption
    end
  end

  private

  def build_item_classes
    active = @index.zero? ? "active" : ""
    class_names("item carousel-item", active)
  end

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
      # Vote section
      render_image_vote_section

      # Image info (copyright, notes)
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

  # Render copyright using ImageCopyright component
  def copyright
    return "" unless @img_instance

    ImageCopyright(
      user: @user,
      image: @img_instance,
      object: @object
    )
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

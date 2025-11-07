# frozen_string_literal: true

# Bootstrap carousel component for displaying image galleries.
#
# Renders a complete carousel with:
# - Optional heading with title and links
# - Carousel slides (CarouselItem components)
# - Previous/Next controls (if multiple images)
# - Thumbnail navigation (optional)
#
# @example
#   render Components::Carousel.new(
#     user: current_user,
#     images: @images,
#     object: @observation,
#     title: "Observation Images",
#     thumbnails: true
#   )
class Components::Carousel < Components::Base
  include Phlex::Rails::Helpers::LinkTo

  # Properties
  prop :images, Array do |value|
    value.respond_to?(:to_a) ? value.to_a : value
  end
  prop :user, _Nilable(User)
  prop :object, _Nilable(Object), default: nil
  prop :size, Components::BaseImage::Size, default: :large
  prop :title, String, default: -> { :IMAGES.t }
  prop :links, String, default: ""
  prop :thumbnails, _Boolean, default: true
  prop :html_id, _Nilable(String), default: nil
  prop :panel_id, _Nilable(String), default: nil

  def view_template
    # Generate HTML ID if not provided
    @html_id ||= generate_html_id

    Panel(panel_id: @panel_id) do |panel|
      # Render heading if thumbnails enabled
      panel.with_heading { @title } if @thumbnails
      panel.with_heading_links { @links } if @links.present?

      # Render carousel or no images message
      if @images&.any?
        render_carousel(panel)
      else
        render_no_images_message(panel)
      end
    end
  end

  private

  def generate_html_id
    type = @object&.type_tag || "image"
    object_id = @object&.id || "unknown"
    "#{type}_#{object_id}_carousel"
  end

  def render_carousel_heading
    div(class: "panel-heading carousel-heading") do
      h4(class: "panel-title") do
        plain(@title)
        span(class: "float-right") { @links } if @links.present?
      end
    end
  end

  def render_carousel(panel)
    panel.with_thumbnail(
      id: @html_id,
      classes: "carousel slide show-carousel",
      data: { ride: "false", interval: "false" }
    ) do
      # Carousel inner (slides)
      div(class: "carousel-inner bg-light", role: "listbox") do
        # Render each carousel item
        @images.each_with_index do |image, index|
          next unless image

          CarouselItem(
            user: @user,
            image: image,
            object: @object,
            size: @size,
            index: index
          )
        end

        # Carousel controls (if multiple images)
        CarouselControls(carousel_id: @html_id) if @images.length > 1
      end

      # Thumbnail navigation (if enabled)
      render_thumbnail_navigation if @thumbnails
    end
  end

  def render_thumbnail_navigation
    ol(class: "carousel-indicators panel-footer py-2 px-0 mb-0") do
      @images.each_with_index do |image, index|
        next unless image

        CarouselThumbnail(
          user: @user,
          image: image,
          index: index,
          html_id: @html_id
        )
      end
    end
  end

  def render_no_images_message(panel)
    panel.with_thumbnail(
      classes: "p-4 my-5 w-100 h-100 text-center h3 text-muted"
    ) do
      plain(:show_observation_no_images.l)
    end
  end
end

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
  prop :images, Array
  prop :user, _Nilable(User)
  prop :object, _Nilable(Object), default: nil
  prop :size, Components::BaseImage::Size, default: :large
  prop :title, String, default: -> { :IMAGES.t }
  prop :links, String, default: ""
  prop :thumbnails, _Boolean, default: true
  prop :html_id, _Nilable(String), default: nil

  def view_template
    # Generate HTML ID if not provided
    final_html_id = @html_id || generate_html_id

    # Render heading if thumbnails enabled
    render_carousel_heading if @thumbnails

    # Render carousel or no images message
    if @images&.any?
      render_carousel(final_html_id)
    else
      render_no_images_message
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
        span(class: "float-right") { unsafe_raw(@links) }
      end
    end
  end

  def render_carousel(final_html_id)
    div(
      id: final_html_id,
      class: "carousel slide show-carousel",
      data: { ride: "false", interval: "false" }
    ) do
      # Carousel inner (slides)
      div(class: "carousel-inner bg-light", role: "listbox") do
        # Render each carousel item
        @images.each_with_index do |image, index|
          next unless image

          render(Components::CarouselItem.new(
                   user: @user,
                   image: image,
                   object: @object,
                   size: @size,
                   index: index
                 ))
        end

        # Carousel controls (if multiple images)
        if @images.length > 1
          unsafe_raw(render_carousel_controls(final_html_id))
        end
      end

      # Thumbnail navigation (if enabled)
      render_thumbnail_navigation(final_html_id) if @thumbnails
    end
  end

  def render_carousel_controls(carousel_id)
    [
      control_button(carousel_id, :prev),
      control_button(carousel_id, :next)
    ].safe_join
  end

  def control_button(carousel_id, direction)
    position = direction == :prev ? "left" : "right"

    link_to("##{carousel_id}",
            class: "#{position} carousel-control",
            role: "button",
            data: { slide: direction.to_s }) do
      render_control_button_content(direction)
    end
  end

  def render_control_button_content(direction)
    icon = direction == :prev ? "chevron-left" : "chevron-right"
    label = direction == :prev ? :PREV : :NEXT

    div(class: "btn") do
      span(class: "glyphicon glyphicon-#{icon}", aria: { hidden: "true" })
      span(label.l, class: "sr-only")
    end
  end

  def render_thumbnail_navigation(carousel_id)
    ol(class: "carousel-indicators panel-footer py-2 px-0 mb-0") do
      @images.each_with_index do |image, index|
        next unless image

        render(Components::CarouselThumbnail.new(
                 user: @user,
                 image: image,
                 index: index,
                 html_id: carousel_id
               ))
      end
    end
  end

  def render_no_images_message
    div(
      class: "p-4 my-5 w-100 h-100 text-center h3 text-muted"
    ) do
      plain(:show_observation_no_images.l)
    end
  end

  def helpers
    @helpers ||= ApplicationController.helpers
  end

  def safe_join(array, separator = nil)
    helpers.safe_join(array, separator)
  end
end

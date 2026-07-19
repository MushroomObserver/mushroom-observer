# frozen_string_literal: true

module Views::Controllers::Images
  class Show
    # Top-left panel on the image show page: image-controls bar
    # (rotate / mirror / original / EXIF links), the interactive
    # image itself, the vote interface (when logged in), and the
    # original filename caption when the owner shares it.
    class ImagePanel < Views::Base
      prop :image, ::Image
      prop :size, _Nilable(_Union(::Symbol, ::String)), default: nil

      def view_template
        # Subscribes this page to Image#broadcast_processed_update's
        # interactive-size broadcast (rendered as a plain top-level
        # statement, not inside the Panel(...) block below -- see
        # Components::Matrix::Box for why that placement would
        # silently never emit anything).
        turbo_stream_from([@image, :processed])
        render(::Components::Panel.new(panel_id: "image_panel")) do |panel|
          panel.with_heading(
            classes:
              "text-center small font-weight-normal image-controls"
          ) { render_controls }
          panel.with_body { render_body }
        end
      end

      private

      # --- Heading: rotate / mirror / original / EXIF ---------------

      def render_controls
        render_transform_controls if permission?(@image)
        render(::Components::Image::OriginalLink.new(image: @image))
        plain(" | ")
        render(::Components::Image::EXIFLink.new(image_id: @image.id))
      end

      def render_transform_controls
        render_transform_button(:rotate_left, :image_show_rotate_left)
        plain(" | ")
        render_transform_button(:rotate_right, :image_show_rotate_right)
        plain(" | ")
        render_transform_button(:mirror, :image_show_mirror)
        plain(" | ")
      end

      def render_transform_button(operation, label_key)
        Button(
          type: :put,
          name: label_key.t,
          target: transform_image_path(id: @image.id,
                                       op: operation, size: @size),
          variant: :strip, icon: nil
        )
      end

      # --- Body: interactive image + vote + original filename ------

      def render_body
        InteractiveImage(
          user: current_user, image: @image,
          size: :huge, image_link: "#",
          extra_classes: "huge-image", votes: false
        )
        div(class: "mt-3 text-center") do
          render_vote_interface if current_user
          render_original_name if show_original_name?
        end
      end

      def render_vote_interface
        render(::Components::Image::VoteInterface.new(
                 user: current_user, image: @image, votes: true
               ))
      end

      def show_original_name?
        @image.original_name.present? && (
          permission?(@image) ||
          @image.user&.keep_filenames == "keep_and_show"
        )
      end

      def render_original_name
        plain(@image.original_name)
      end
    end
  end
end

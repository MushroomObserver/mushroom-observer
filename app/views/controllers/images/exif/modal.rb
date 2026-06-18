# frozen_string_literal: true

module Views::Controllers::Images
  module EXIF
    # Turbo-stream lightbox modal triggered from
    # `Components::Image::EXIFLink`. Replaces the ERB
    # `shared/_modal.erb` + `images/exif/_data.erb` pair the
    # controller used to render via the legacy
    # `render(partial: "shared/modal", locals: { body: "images/exif/data" })`
    # shape. A Phlex view wrapper is required because controller `render`
    # doesn't thread the block through to a Phlex component's
    # `view_template(&block)` — every `Components::Modal` caller in this
    # codebase goes through a Phlex view, not a controller render call.
    class Modal < Views::FullPageBase
      prop :image, ::Image
      prop :data, _Nilable(_Array(_Array(::String))), default: nil
      prop :success, _Boolean, default: true
      prop :error_text, _Nilable(::String), default: nil

      def view_template
        render(::Components::Modal.new(
                 id: "modal_image_exif_#{@image.id}",
                 title: :exif_data_for_image.t(image: @image.id),
                 user: current_user
               )) do |m|
          m.with_body do
            if @success
              render(DataTable.new(data: @data))
            else
              # `@error_text` is raw exiftool output (stderr on failure);
              # render as escaped plain text in a <pre> to preserve
              # formatting without an HTML-injection vector.
              pre { plain(@error_text.to_s) }
            end
          end
        end
      end
    end
  end
end

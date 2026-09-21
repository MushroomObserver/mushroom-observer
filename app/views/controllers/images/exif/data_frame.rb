# frozen_string_literal: true

module Views::Controllers::Images
  module EXIF
    # Turbo Frame content for the lightbox "Show EXIF Header" modal.
    # See issue #5369 for why this loads lazily instead of at
    # modal-open time.
    class DataFrame < Views::Base
      prop :img_id, ::String
      prop :data, _Nilable(_Array(_Array(::String))), default: nil
      prop :success, _Boolean, default: true
      prop :error_text, _Nilable(::String), default: nil

      def view_template
        turbo_frame_tag(frame_id) do
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

      private

      def frame_id
        "exif_data_frame_#{@img_id}"
      end
    end
  end
end

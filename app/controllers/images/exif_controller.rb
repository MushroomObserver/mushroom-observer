# frozen_string_literal: true

# Images::EXIFController
module Images
  class EXIFController < ApplicationController
    before_action :login_required

    # Linked from lightbox and show_image
    # Returns EXIF header of image as HTML table.
    def show
      @image = Image.find(params[:id])

      respond_to do |format|
        format.html { render_exif_html }
        format.turbo_stream { render_exif_modal }
      end
    end

    private

    # The full-page view reads EXIF synchronously -- a less-traveled
    # path (reached only via Tab::Image::EXIFShow) than the lightbox
    # modal below, which needs to stay responsive for every image
    # page's "Show EXIF Header" link.
    def render_exif_html
      data, status, result = @image.read_exif_data
      if status.success?
        render(Views::Controllers::Images::EXIF::Show.new(
                 image: @image, data: data
               ))
      else
        render(plain: result, status: :internal_server_error)
      end
    end

    # The EXIF header itself loads lazily -- see EXIFDataJob and
    # Views::Controllers::Images::EXIF::Modal. Controller `render`
    # can't thread a block to `Components::Modal`'s
    # `view_template(&block)`, so the modal is wrapped in a Phlex view
    # that does the `with_body` slot wiring.
    def render_exif_modal
      render(Views::Controllers::Images::EXIF::Modal.new(image: @image),
             layout: false)
    end
  end
end

# frozen_string_literal: true

# Images::EXIFController
module Images
  class EXIFController < ApplicationController
    before_action :login_required

    # Linked from lightbox and show_image
    # Returns EXIF header of image as HTML table.
    def show
      @image = Image.find(params[:id])
      @data, @status, @result = @image.read_exif_data

      respond_to do |format|
        format.html { render_exif_html }
        format.turbo_stream { render_exif_modal }
      end
    end

    private

    def render_exif_html
      if @status.success?
        render(Views::Controllers::Images::EXIF::Show.new(
                 image: @image, data: @data
               ))
      else
        render(plain: @result, status: :internal_server_error)
      end
    end

    # Controller `render` can't thread a block to `Components::Modal`'s
    # `view_template(&block)`, so the modal is wrapped in a Phlex view
    # that does the `with_body` slot wiring.
    def render_exif_modal
      status = @status.success? ? :ok : :internal_server_error
      render(Views::Controllers::Images::EXIF::Modal.new(
               image: @image, data: @data,
               success: @status.success?, error_text: @result
             ), layout: false, status: status)
    end
  end
end

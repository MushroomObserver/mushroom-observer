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
        format.html
        format.turbo_stream do
          identifier = "image_exif_#{@image.id}"
          title = :exif_data_for_image.t(image: @image.id)
          fallback = @status ? nil : @result
          render(partial: "shared/modal",
                 locals: { identifier: identifier, title: title,
                           body: "images/exif/data", fallback: fallback })
        end
      end
    end
  end
end

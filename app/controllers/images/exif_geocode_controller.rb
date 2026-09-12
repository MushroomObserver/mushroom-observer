# frozen_string_literal: true

module Images
  class EXIFGeocodeController < ApplicationController
    before_action :login_required

    # Lazy-loaded fragment for Components::Form::CameraInfo. A Turbo
    # Frame fetches this after the edit page has rendered. This keeps
    # the slow Image#read_exif_geocode call off the page's request.
    # See issue #5369.
    #
    # `read_only` and `date_differs` come from CameraInfo's props. The
    # caller already computed them cheaply from the database, so this
    # action just passes them through.
    def show
      @image = Image.find(params[:id])
      @data = @image.read_exif_geocode(hide_gps: false) || {}
      render(Views::Controllers::Images::EXIFGeocode::Show.new(**view_props),
             layout: false)
    end

    private

    def view_props
      {
        img_id: @image.id.to_s,
        lat: @data[:lat],
        lng: @data[:lng],
        alt: @data[:alt],
        date: @data[:date] || @image.when&.strftime("%d-%B-%Y"),
        date_differs: params[:date_differs] == "true",
        read_only: params[:read_only] == "true"
      }
    end
  end
end

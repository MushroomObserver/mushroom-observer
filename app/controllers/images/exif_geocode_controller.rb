# frozen_string_literal: true

module Images
  class EXIFGeocodeController < ApplicationController
    before_action :login_required

    # Turbo Frame endpoint for Components::Form::CameraInfo. Enqueues
    # EXIFGeocodeJob to do the slow work (Image#read_exif_geocode
    # shells out to exiftool) and responds immediately with a loading
    # placeholder for the same frame. The job broadcasts the content
    # when it finishes. See issue #5369 for why this doesn't read the
    # EXIF data inline in this action.
    #
    # `read_only` and `date_differs` come from CameraInfo's props. The
    # caller already computed them cheaply from the database, so this
    # action just passes them through to the job.
    def show
      @image = Image.find(params[:id])
      EXIFGeocodeJob.perform_later(@image.id, read_only: read_only_param?,
                                              date_differs: date_differs_param?)
      render(Views::Controllers::Images::EXIFGeocode::Loading.new(
               img_id: @image.id.to_s
             ), layout: false)
    end

    private

    def read_only_param?
      params[:read_only] == "true"
    end

    def date_differs_param?
      params[:date_differs] == "true"
    end
  end
end

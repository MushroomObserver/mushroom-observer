# frozen_string_literal: true

# Images::EXIFController
module Images
  class EXIFController < ApplicationController
    require "English"
    require("open3")

    before_action :login_required

    GPS_TAGS = /latitude|longitude|gps/i

    # Linked from lightbox and show_image
    # Get EXIF header of image, return as HTML table.
    def show
      @image = Image.find(params[:id])
      hide_gps = @image.observations.any?(&:gps_hidden)

      if @image.transferred
        cmd = Shellwords.escape("script/exiftool_remote")
        url = Shellwords.escape(@image.original_url)
        @result, @status = Open3.capture2e(cmd, url)
      else
        cmd  = Shellwords.escape("exiftool")
        file = Shellwords.escape(@image.local_file_name("orig"))
        @result, @status = Open3.capture2e(cmd, file)
      end

      @data = @status.success? ? parse_exif_data(@result, hide_gps) : nil
      respond_to do |format|
        format.html
        format.js
      end
    end

    def test_parse_exif_data(result, hide_gps)
      parse_exif_data(result, hide_gps)
    end

    private

    def parse_exif_data(result, hide_gps)
      result.fix_utf8.split("\n").
        map { |line| line.split(/\s*:\s+/, 2) }.
        select { |_key, val| val != "" && val != "n/a" }.
        reject { |key, _val| hide_gps && key.match(GPS_TAGS) }
    end
  end
end

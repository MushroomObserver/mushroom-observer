# frozen_string_literal: true

require("open3")

GPS_TAGS = /latitude|longitude|gps/i.freeze

# see ajax_controller.rb
class AjaxController
  require "English"

  # Get EXIF header of image, return as HTML table.
  def exif
    image = Image.find(@id)
    hide_gps = image.observations.any?(&:gps_hidden)
    if image.transferred
      cmd = Shellwords.escape("script/exiftool_remote")
      url = Shellwords.escape(image.original_url)
      result, status = Open3.capture2e(cmd, url)
    else
      cmd  = Shellwords.escape("exiftool")
      file = Shellwords.escape(image.local_file_name("orig"))
      result, status = Open3.capture2e(cmd, file)
    end
    if status.success?
      render_exif_data(result, hide_gps)
    else
      render(plain: result, status: :internal_server_error)
    end
  end

  def test_parse_exif_data(result, hide_gps)
    parse_exif_data(result, hide_gps)
  end

  private

  def render_exif_data(result, hide_gps)
    @data = parse_exif_data(result, hide_gps)
    render(inline: "<%= make_table(@data) %>")
  end

  def parse_exif_data(result, hide_gps)
    result.split("\n").
      map { |line| line.split(/\s*:\s+/, 2) }.
      select { |_key, val| val != "" && val != "n/a" }.
      reject { |key, _val| hide_gps && key.match(GPS_TAGS) }
  end
end

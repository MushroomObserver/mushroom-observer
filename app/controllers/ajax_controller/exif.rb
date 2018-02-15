# see ajax_controller.rb
class AjaxController
  require "English"

  # Get EXIF header of image, return as HTML table.
  def exif
    image = Image.find(@id)
    result = `wget -qO- '#{image.original_url}' | exiftool - 2>&1`
    if $CHILD_STATUS.success?
      render_exif_data(result)
    else
      render(text: result, status: 500)
    end
  end

  private

  def render_exif_data(result)
    @data = result.split("\n").
            map { |line| [line.split(/\s*:\s+/, 2)] }.
            select { |_key, val| val != "" && val != "n/a" }
    render(inline: "<%= make_table(@data) %>")
  end
end

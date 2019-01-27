# see ajax_controller.rb
class AjaxController
  # Mark an object for export. Renders updated export controls.
  # type::  Type of object.
  # id::    Object id.
  # value:: '0' or '1'
  def export
    @user  = session_user!
    @image = Image.find(@id)
    raise "Permission denied." unless @user.in_group?("reviewers")
    raise "Bad value." if @value != "0" && @value != "1"

    export_image(@image, @value)
  end

  private

  def export_image(image, value)
    @image = image
    @image.ok_for_export = (value == "1")
    @image.save_without_our_callbacks
    render(inline: "<%= image_exporter(@image.id, @image.ok_for_export) %>")
  end
end

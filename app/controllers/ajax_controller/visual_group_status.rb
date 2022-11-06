# frozen_string_literal: true

# see ajax_controller.rb
module AjaxController::VisualGroupStatus
  # Set status. Renders new set of status controls for HTML page.
  # type::  Type of object.
  # id::    ID of visual group.
  # value:: Value of status.
  def visual_group_status
    @user = session_user!
    image = Image.find_by(id: params["imgid"])
    visual_group = VisualGroup.find_by(id: @id)
    return unless image && visual_group

    vgi = visual_group.visual_group_images.find_by(image: image)
    included = (@value == "true")
    debugger
    if params["need"] == "true"
      vgi&.destroy
    elsif vgi
      vgi.included = @value
      vgi.save!
    else
      VisualGroupImage.create!(visual_group: visual_group, image: image, included: included)
    end
  end
end

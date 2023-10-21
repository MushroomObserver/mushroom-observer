# frozen_string_literal: true

# see ajax_controller.rb
module AjaxController::VisualGroupStatus
  # Set status. Renders new set of status controls for HTML page.
  # type::  Type of object.
  # id::    ID of visual group.
  # value:: Value of status.
  def visual_group_status
    @user = session_user!
    image_id = params["imgid"]
    @value = "" unless Image.find_by(id: image_id)
    visual_group = VisualGroup.find_by(id: @id)
    return unless visual_group

    status = update_visual_group_image(visual_group, image_id)
    render(partial: "visual_groups/visual_group_status_links",
           locals: { visual_group: visual_group,
                     image_id: image_id,
                     status: status })
  end

  def update_visual_group_image(visual_group, image_id)
    vgi = visual_group.visual_group_images.find_by(image_id: image_id)
    status = (@value == "true")
    if @value == ""
      vgi&.destroy
      status = nil
    elsif vgi
      vgi.included = status
      vgi.save!
    else
      VisualGroupImage.create!(visual_group: visual_group,
                               image_id: image_id,
                               included: status)
    end
    status
  end
end

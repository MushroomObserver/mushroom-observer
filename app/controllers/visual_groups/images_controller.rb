# frozen_string_literal: true

module VisualGroups
  class ImagesController < ApplicationController
    before_action :login_required

    def update
      @user = User.current
      image_id = params[:id]
      status = params[:status]
      status = "" unless Image.find_by(id: image_id)
      visual_group = VisualGroup.find_by(id: params[:visual_group_id])
      return unless visual_group

      included = update_visual_group_image(visual_group, image_id, status)
      debugger

      # this is a turbo response
      render(partial: "visual_groups/images/update",
             locals: { visual_group: visual_group,
                       image_id: image_id, status: included })
    end

    private

    def update_visual_group_image(visual_group, image_id, status)
      vgi = visual_group.visual_group_images.find_by(image_id: image_id)
      included = (status == "true")
      if status == ""
        vgi&.destroy
        included = nil
      elsif vgi
        vgi.included = included
        vgi.save!
      else
        VisualGroupImage.create!(visual_group: visual_group,
                                 image_id: image_id,
                                 included: included)
      end
      included
    end
  end
end

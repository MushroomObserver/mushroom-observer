# frozen_string_literal: true

module VisualGroups
  class ImagesController < ApplicationController
    def update
      @user = session_user!
      image_id = params[:id]
      @status = params[:status]
      @status = "" unless Image.find_by(id: image_id)
      visual_group = VisualGroup.find_by(id: params[:visual_group_id])
      return unless visual_group

      status = update_visual_group_image(visual_group, image_id)

      # This can do a turbo_stream
      render(partial: "visual_groups/visual_group_status_links",
             locals: { visual_group: visual_group,
                       image_id: image_id,
                       status: status })
    end

    def update_visual_group_image(visual_group, image_id)
      vgi = visual_group.visual_group_images.find_by(image_id: image_id)
      included = (@status == "true")
      if @status == ""
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

# frozen_string_literal: true

module VisualGroups
  class ImagesController < ApplicationController
    before_action :login_required

    def update
      image_id = params[:id]
      status = params[:status]
      status = "" unless Image.find_by(id: image_id)
      visual_group = VisualGroup.find_by(id: params[:visual_group_id])
      return unless visual_group

      included = update_visual_group_image(visual_group, image_id, status)
      render_status_links_replace(visual_group, image_id, included)
    end

    private

    # Turbo response: replace just the status-links block for the
    # image whose status flipped. The same Phlex view renders both
    # in the matrix grid and here, so the replacement is identical
    # to what the next full page-load would emit.
    def render_status_links_replace(visual_group, image_id, included)
      links_view = Views::Controllers::VisualGroups::StatusLinks.new(
        visual_group: visual_group, image_id: image_id.to_i,
        status: included
      )
      render(turbo_stream: turbo_stream.replace(
        "visual_group_status_links_#{image_id}", links_view
      ))
    end

    def update_visual_group_image(visual_group, image_id, status)
      vgi = visual_group.visual_group_images.find_by(image_id: image_id)
      included = (status == "true") # coerce Boolean from status text
      if status == "" # restore the nil value if nil, for "Needs Review"
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

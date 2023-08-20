# frozen_string_literal: true

# Glue table between observations and images.
class VisualGroupImage < ApplicationRecord
  belongs_to :visual_group
  belongs_to :image

  def image_in_group?(visual_group_id)
    image.visual_groups.pluck(:id).include?(visual_group_id)
  end
end

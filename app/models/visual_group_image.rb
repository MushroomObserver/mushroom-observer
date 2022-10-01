# frozen_string_literal: true

# Glue table between observations and images.
class VisualGroupImage < ApplicationRecord
  belongs_to :visual_group
  belongs_to :image
end

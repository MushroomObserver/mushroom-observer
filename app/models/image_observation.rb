# frozen_string_literal: true

# Glue table between observations and images.
class ImageObservation < ApplicationRecord
  belongs_to :observation
  belongs_to :image
end

# frozen_string_literal: true

class VisualGroup < ApplicationRecord
  has_many :visual_group_images, dependent: :destroy
  has_many :images, through: :visual_group_images
  has_one :visual_model

  def add_image(image)
    images << image
    save
  end

  def add_images(new_images)
    new_images.each do |image|
      if image.visual_group(visual_model) != self
        add_image(image)
      end
    end
  end
end

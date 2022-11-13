# frozen_string_literal: true

class VisualGroup < ApplicationRecord
  has_many :visual_group_images, dependent: :destroy
  has_many :images, through: :visual_group_images
  belongs_to :visual_model

  def image_count(status=true)
    return visual_group_images.count if status.nil?
    return visual_group_images.where(included: true).count if status

    visual_group_images.where(included: false).count
  end

  def add_image(image)
    images << image
    save
  end

  def add_images(new_images)
    new_images.each do |image|
      add_image(image) if image.visual_group(visual_model) != self
    end
  end
end

# frozen_string_literal: true

class VisualGroup < ApplicationRecord
  has_many :names, dependent: :nullify

  def add_name(name)
    name.visual_group = self
    name.save
  end

  def add_names(new_names)
    new_names.each do |name|
      add_name(name) if name.visual_group.blank?
    end
  end

  def total_observations
    total = 0
    names.each do |name|
      total += name.observations.count
    end
    total
  end

  def total_images
    total = 0
    names.each do |name|
      name.observations.each do |obs|
        total += obs.images.count
      end
    end
    total
  end
end

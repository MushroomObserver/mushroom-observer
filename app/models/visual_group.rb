# frozen_string_literal: true

class VisualGroup < ApplicationRecord
  belongs_to :group_name, class_name: "Name"
  has_many :names, dependent: :nullify

  def add_names(new_names)
    new_names.each do |name|
      next if name.visual_group.present?

      name.visual_group = self
      name.save
    end
  end

  def total_observations
    total = 0
    names.each do |name|
      total += name.observations.count
    end
    total
  end
end

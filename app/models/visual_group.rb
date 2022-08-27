# frozen_string_literal: true

class VisualGroup < ApplicationRecord
  belongs_to :group_name, class_name: "Name"
  has_many :names, dependent: :nullify

  def add_names(names)
    names.each do |name|
      next if name.visual_group.present?

      name.visual_group = self
      name.save
    end
  end
end

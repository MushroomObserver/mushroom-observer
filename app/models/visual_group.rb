class VisualGroup < ApplicationRecord
  belongs_to :group_name, class_name: "Name"
  has_many :names

  def add_names(names)
    for name in names
      next if name.visual_group.present?

      name.visual_group = self
      name.save
    end
  end
end

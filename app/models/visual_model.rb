# frozen_string_literal: true

require "extensions"

class VisualModel < AbstractModel
  has_many :visual_groups, dependent: :destroy

  validates :name, presence: {
    message: proc { :cannot_be_blank.t }
  }
  validates :name, format: {
    without: /\t/, message: proc { :cannot_include_tabs.t }
  }

  def to_json(_)
    {
      name: name,
      labels: visual_groups.map do |vg|
        {
          name: vg.name,
          images: vg.included_image_ids
        }
      end
    }.to_json
  end

  def image_counts(included = true)
    VisualGroupImage.includes(:visual_group).where(
      visual_group: { visual_model_id: id },
      included: included
    ).group(:visual_group_id).count
  end
end

# frozen_string_literal: true

class VisualModel < AbstractModel
  has_many :visual_groups, dependent: :destroy

  validates :name, presence: {
    message: proc { :cannot_be_blank.t }
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
end

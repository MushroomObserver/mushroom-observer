# frozen_string_literal: true

class VisualModel < AbstractModel
  has_many :visual_groups, dependent: :destroy

  validates :name, presence: {
    message: proc { :cannot_be_blank.t }
  }
end

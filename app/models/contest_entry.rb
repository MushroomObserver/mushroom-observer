# frozen_string_literal: true

class ContestEntry < AbstractModel
  belongs_to :image
  belongs_to :alternate_image, class_name: "Image"
  has_many :contest_votes, dependent: :destroy

  def title
    "#{:CONTEST_ENTRY.t}: #{copyright_holder}"
  end

  def copyright_holder
    image&.copyright_holder || ""
  end
end

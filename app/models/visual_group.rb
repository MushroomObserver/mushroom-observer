# frozen_string_literal: true

class VisualGroup < AbstractModel
  has_many :visual_group_images, dependent: :destroy
  has_many :images, through: :visual_group_images
  belongs_to :visual_model

  validates :name, presence: {
    message: proc { :cannot_be_blank.t }
  }

  def image_count(status = true)
    return visual_group_images.count if status.nil? || status == "needs_review"

    if status && status != "excluded"
      return visual_group_images.where(included: true).count
    end

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

  def distinct_names
    VisualGroup.connection.select_rows(VisualGroupNames.new(id).sql_query)
  end

  def included_image_ids
    visual_group_images.where(included: true).pluck(:image_id)
  end
end

# frozen_string_literal: true

# "Edit image" link.
class Tab::Image::Edit < Tab::Base
  def initialize(image:)
    super()
    @image = image
  end

  def title
    :edit_object.t(type: :image)
  end

  def path
    edit_image_path(@image.id)
  end

  def model
    @image
  end
end

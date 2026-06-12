# frozen_string_literal: true

# "Send commercial inquiry about this image" link. Caller is
# responsible for checking that the image's user accepts commercial
# inquiry email before instantiating.
class Tab::Image::CommercialInquiry < Tab::Base
  def initialize(image:)
    super()
    @image = image
  end

  def title
    :image_show_inquiry.t
  end

  def path
    new_commercial_inquiry_for_image_path(@image.id)
  end

  def model
    @image
  end
end

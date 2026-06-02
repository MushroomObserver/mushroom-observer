# frozen_string_literal: true

# Action-nav for the image EXIF show page: back to the image.
class Tab::Image::EXIFShow < Tab::Collection
  def initialize(image:)
    super()
    @image = image
  end

  private

  def tabs
    [Tab::Object::Return.new(object: @image)]
  end
end

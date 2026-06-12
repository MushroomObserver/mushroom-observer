# frozen_string_literal: true

class Tab::Observation::ImagesEdit < Tab::Collection
  def initialize(image:)
    super()
    @image = image
  end

  private

  def tabs
    [Tab::Object::Return.new(object: @image)]
  end
end

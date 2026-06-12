# frozen_string_literal: true

# "Destroy image" button-tab. The renderer treats `path` as the
# `destroy_button` target since `html_options[:button] == :destroy`.
class Tab::Image::Destroy < Tab::Base
  def initialize(image:)
    super()
    @image = image
  end

  def title
    :destroy_object.t(type: :image)
  end

  def path
    @image
  end

  def html_options
    { button: :destroy }
  end

  def model
    @image
  end
end

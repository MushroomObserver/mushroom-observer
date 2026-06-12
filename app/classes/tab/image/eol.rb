# frozen_string_literal: true

# External "EOL" link for an image (if EOL has it).
class Tab::Image::Eol < Tab::Base
  def initialize(image:)
    super()
    @image = image
  end

  def title
    "EOL"
  end

  def path
    @image.eol_url
  end

  def html_options
    { target: "_blank", rel: "noopener" }
  end
end

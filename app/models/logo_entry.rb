# frozen_string_literal: true

class LogoEntry < AbstractModel
  belongs_to :image

  def title
    "#{:LOGO_ENTRY.t}: #{copyright_holder}"
  end

  def copyright_holder
    image&.copyright_holder || ""
  end
end

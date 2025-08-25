# frozen_string_literal: true

# Represents a single field on a mushroom observation label
class LabelField
  attr_reader :name, :value

  def initialize(name, value)
    @name = name
    @value = value
  end

  # Renders the field as a formatted line on the PDF
  def render(pdf, options = {})
    return if value.nil? || value.to_s.strip.empty?

    label_text = "#{name}: "
    label_width = 0
    pdf.font("app/assets/fonts/DejaVuSerif-Bold.ttf") do
      label_width = pdf.width_of(label_text, size: 10)
      pdf.draw_text(label_text, at: [0, pdf.cursor], size: 10)
    end
    
    pdf.font("app/assets/fonts/DejaVuSerif.ttf") do
      pdf.draw_text(value, at: [label_width, pdf.cursor], size: 10)
      pdf.move_down(pdf.height_of(value, size: 10))
    end
  end
end

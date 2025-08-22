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

    formatted_text = "<b>#{name}:</b> #{value}"
    pdf.text(formatted_text,
             size: 10,
             inline_format: true,
             **options)
  end
end

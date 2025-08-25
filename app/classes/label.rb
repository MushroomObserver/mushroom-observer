# frozen_string_literal: true

# Represents a single 5"x3" label for one mushroom observation
class Label
  LABEL_WIDTH = 5.in
  LABEL_HEIGHT = 3.in
  MARGIN = 0.25.in
  QR_CODE_SIZE = 0.75.in

  attr_reader :observation, :font_family

  def initialize(observation, font_family = "DejaVu Sans")
    @observation = observation
    @font_family = font_family
  end

  # Renders the label within the specified bounds
  def render(pdf, x_coord, y_coord)
    # Create a bounding box for the label content (excluding margins)
    content_width = LABEL_WIDTH - (2 * MARGIN)
    content_height = LABEL_HEIGHT - (2 * MARGIN)

    # Get fields from the observation using ObservationFields
    observation_fields = ObservationFields.new(observation)
    label_fields = observation_fields.label_fields
    qr_fields = observation_fields.qr_fields

    # Calculate space allocation
    qr_area_height = qr_fields.any? ? (QR_CODE_SIZE + 0.2.in) : 0
    text_area_height = content_height - qr_area_height

    pdf.bounding_box([x_coord + MARGIN, y_coord - MARGIN],
                     width: content_width,
                     height: content_height) do
      # Set font for the entire label
      pdf.font(font_family)

      # Render text fields in the upper portion
      render_text_fields(pdf, label_fields, text_area_height)

      # Render QR codes at the bottom
      render_qr_codes(pdf, qr_fields, content_width) if qr_fields.any?
    end
  end

  # Draws a border around the label (used when multiple labels per page)
  def draw_border(pdf, x_coord, y_coord)
    pdf.stroke_color("999999")
    pdf.line_width(0.5)
    pdf.stroke_rectangle([x_coord, y_coord], LABEL_WIDTH, LABEL_HEIGHT)
    pdf.stroke_color("000000") # Reset to black
    pdf.line_width(1) # Reset line width
  end

  private

  def render_text_fields(pdf, fields, available_height)
    pdf.bounding_box([0, pdf.cursor], width: pdf.bounds.width,
                                      height: available_height) do
      fields.each do |field|
        break if pdf.cursor <= 0 # Stop if we run out of space

        field.render(pdf)
        pdf.move_down(2) # Small spacing between fields
      end
    end
  end

  def render_qr_codes(pdf, qr_fields, content_width)
    return if qr_fields.empty?

    # Calculate positions for QR codes (distribute evenly across width)
    qr_count = qr_fields.length
    available_width = content_width - (qr_count * QR_CODE_SIZE)
    spacing = qr_count > 1 ? available_width / (qr_count + 1) : available_width / 2

    # Position QR codes at the bottom of the label
    qr_y = QR_CODE_SIZE + 0.1.in

    qr_fields.each_with_index do |qr_field, index|
      qr_x = spacing + (index * (QR_CODE_SIZE + spacing))
      qr_field.render(pdf, qr_x, qr_y, QR_CODE_SIZE)
    end
  end
end

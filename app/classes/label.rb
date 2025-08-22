# frozen_string_literal: true

# Represents a single 5"x3" label for one mushroom observation
class Label
  LABEL_WIDTH = 5.in
  LABEL_HEIGHT = 3.in
  MARGIN = 0.25.in

  attr_reader :observation

  def initialize(observation)
    @observation = observation
  end

  # Renders the label within the specified bounds
  def render(pdf, x_coord, y_coord)
    # Create a bounding box for the label content (excluding margins)
    content_width = LABEL_WIDTH - (2 * MARGIN)
    content_height = LABEL_HEIGHT - (2 * MARGIN)

    pdf.bounding_box([x_coord + MARGIN, y_coord - MARGIN],
                     width: content_width,
                     height: content_height) do
      # Get label fields from the observation
      fields = ObservationFields.new(observation).fields

      # Set font for the entire label
      # pdf.font "#{Prawn::ManualBuilder::DATADIR}/fonts/DejaVuSans.ttf"

      # Render each field
      fields.each do |field|
        field.render(pdf)
        pdf.move_down(2) # Small spacing between fields
      end
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
end

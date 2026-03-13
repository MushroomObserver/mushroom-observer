# frozen_string_literal: true

# Represents a single 5"x3" label for one mushroom observation
class ObservationLabels::Label
  LABEL_WIDTH = 5.in
  LABEL_HEIGHT = 3.in
  X_MARGIN = 0.25.in
  Y_MARGIN = 0.5.in
  QR_CODE_SIZE = 0.75.in

  attr_reader :observation, :font_family, :pdf

  def initialize(observation, font_family = "DejaVu Sans")
    @observation = observation
    @font_family = font_family
  end

  # Renders the label within the specified bounds
  def render(pdf, x_coord, y_coord)
    @pdf = pdf
    label_dimensions = calculate_label_dimensions
    observation_fields = prepare_observation_fields
    space_allocation = calculate_space_allocation(label_dimensions,
                                                  observation_fields)

    render_label_content(x_coord, y_coord, label_dimensions,
                         observation_fields, space_allocation)
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

  def calculate_label_dimensions
    content_width = LABEL_WIDTH - (2 * X_MARGIN)
    content_height = LABEL_HEIGHT - (2 * Y_MARGIN)

    {
      content_width: content_width,
      content_height: content_height,
      x_margin: X_MARGIN,
      y_margin: Y_MARGIN
    }
  end

  def prepare_observation_fields
    observation_fields = ObservationLabels::Fields.new(observation)

    {
      label_fields: observation_fields.label_fields,
      qr_fields: observation_fields.qr_fields
    }
  end

  def calculate_space_allocation(dimensions, fields)
    qr_area_height = fields[:qr_fields].any? ? (QR_CODE_SIZE + 0.2.in) : 0
    text_area_height = dimensions[:content_height] - qr_area_height

    {
      qr_area_height: qr_area_height,
      text_area_height: text_area_height
    }
  end

  def render_label_content(x_coord, y_coord, dimensions, fields,
                           space_allocation)
    bounding_box_x = x_coord + dimensions[:x_margin]
    bounding_box_y = y_coord - dimensions[:y_margin]

    pdf.bounding_box([bounding_box_x, bounding_box_y],
                     width: dimensions[:content_width],
                     height: dimensions[:content_height]) do
      render_content_within_bounds(fields, space_allocation, dimensions)
    end
  end

  def render_content_within_bounds(fields, space_allocation, dimensions)
    pdf.font(font_family)
    render_text_fields(fields[:label_fields],
                       space_allocation[:text_area_height])
    render_qr_content_if_present(fields[:qr_fields],
                                 dimensions[:content_width])
  end

  def render_qr_content_if_present(qr_fields, content_width)
    return unless qr_fields.any?

    render_qr_codes(qr_fields, content_width)
  end

  def render_text_fields(fields, available_height)
    pdf.bounding_box([0, pdf.cursor], width: pdf.bounds.width,
                                      height: available_height) do
      fields.each do |field|
        break if pdf.cursor <= 0 # Stop if we run out of space

        field.render(pdf)
        pdf.move_down(2) # Small spacing between fields
      end
    end
  end

  def render_qr_codes(qr_fields, content_width)
    return if qr_fields.empty?

    code_space = QR_CODE_SIZE * 1.6667
    qr_y = QR_CODE_SIZE + 0.1.in

    qr_fields.each_with_index do |qr_field, index|
      qr_x = content_width - (index + 1) * code_space
      qr_field.render(pdf, qr_x, qr_y, QR_CODE_SIZE)
    end
  end
end

# frozen_string_literal: true

# Represents a single 5"x3" label for one mushroom observation
class Label
  LABEL_WIDTH = 5.in
  LABEL_HEIGHT = 3.in
  MARGIN = 0.25.in
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
    content_width = LABEL_WIDTH - (2 * MARGIN)
    content_height = LABEL_HEIGHT - (2 * MARGIN)

    {
      content_width: content_width,
      content_height: content_height,
      margin: MARGIN
    }
  end

  def prepare_observation_fields
    observation_fields = ObservationFields.new(observation)

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
    bounding_box_x = x_coord + dimensions[:margin]
    bounding_box_y = y_coord - dimensions[:margin]

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

  def count_similar_observations
    # def count_similar_observations(observation)
    # Share a name and a project and occur within a week of each other
    location_filter(
      observation.name.observations.joins(:project_observations).
        where(project_observations: { project_id: observation.project_ids }).
        where(when: week_before..week_after).where.not(id: observation.id)
    ).distinct.count
  end

  def location_filter(results)
    lat = observation.lat || observation.location_lat
    lng = observation.lng || observation.location_lng
    if lat && lng
      results.in_box(north: [90, lat + 1].min,
                     south: [-90, lat - 1].max,
                     east: lng_add(lng, 1),
                     west: lng_add(lng, -1))
    else
      results
    end
  end

  def lng_add(value, offset)
    ((value + offset + 180) % 360) - 180
  end

  def week_before
    observation.when - 1.week
  end

  def week_after
    observation.when + 1.week
  end
end

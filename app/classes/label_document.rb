# frozen_string_literal: true

require "prawn"
require "prawn/measurement_extensions"

# Main document class for generating PDF labels
class LabelDocument
  attr_reader :query, :page_width, :page_height

  def initialize(query, page_width, page_height)
    @query = query
    @page_width = page_width.in
    @page_height = page_height.in
  end

  # Generates the PDF document and returns it as a string

  # Generates the PDF document and returns it as a string
  def generate
    pdf = create_pdf_document
    setup_document(pdf)
    render_observations(pdf)
    pdf.render
  end

  # Method compatible with Rails send_data
  def body
    generate
  end

  def mime_type
    "application/pdf"
  end

  def encoding; end

  def filename
    "observation_labels_#{Date.current}.pdf"
  end

  def header
    {}
  end

  private

  def create_pdf_document
    Prawn::Document.new(
      page_size: [page_width, page_height],
      margin: 0
    )
  end

  def setup_document(pdf)
    register_fonts(pdf)
  end

  def render_observations(pdf)
    observations = query.results
    labels_per_page = calculate_labels_per_page
    draw_borders = labels_per_page > 1

    observations.each_with_index do |observation, index|
      start_new_page_if_needed(pdf, index, labels_per_page)
      render_single_observation(pdf, observation, index, labels_per_page,
                                draw_borders)
    end
  end

  def start_new_page_if_needed(pdf, index, labels_per_page)
    pdf.start_new_page if index.positive? && (index % labels_per_page).zero?
  end

  def render_single_observation(pdf, observation, index, labels_per_page,
                                draw_borders)
    label_position = index % labels_per_page
    x, y = calculate_label_position(label_position)

    label = Label.new(observation)
    label.draw_border(pdf, x, y) if draw_borders
    label.render(pdf, x, y)
  end

  def register_fonts(pdf)
    # Register DejaVu Sans font family
    # Note: In a real Rails app, you'd typically put font files in
    # app/assets/fonts/ and reference them with Rails.root.join('app',
    # 'assets', 'fonts', 'filename.ttf')

    pdf.font_families.update(
      "DejaVu Sans" => {
        normal: "DejaVuSans.ttf",
        bold: "DejaVuSans-Bold.ttf",
        italic: "DejaVuSans-Oblique.ttf",
        bold_italic: "DejaVuSans-BoldOblique.ttf"
      }
    )
  rescue StandardError => e
    # Fallback to Helvetica if DejaVu Sans is not available
    if defined?(Rails)
      Rails.logger.warn("DejaVu Sans font not found, " \
                        "falling back to Helvetica: #{e.message}")
    end
    pdf.font("Helvetica")
  end

  def calculate_labels_per_page
    (page_height / Label::LABEL_HEIGHT).floor
  end

  def calculate_label_position(label_index)
    x = 0
    y = page_height - (label_index * Label::LABEL_HEIGHT)
    [x, y]
  end
end

# frozen_string_literal: true

require "prawn"
require "prawn/measurement_extensions"

# Main document class for generating PDF labels
class ObservationLabels
  attr_reader :query, :page_width, :page_height

  def initialize(query)
    @query = query
    if query.results.one?
      @page_width = 5.in
      @page_height = 3.in
    else
      @page_width = 8.5.in
      @page_height = 11.in
    end
  end

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

  def http_disposition
    "inline"
  end

  def encoding
    "ASCII-8BIT"
  end

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
    @font_family = font_family
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

    label = ObservationLabels::Label.new(observation, @font_family)
    label.draw_border(pdf, x, y) if draw_borders
    label.render(pdf, x, y)
  end

  def register_fonts(pdf)
    # Use fonts from Rails app/assets/fonts directory

    font_path = Rails.root.join("app/assets/fonts")
    register_app_fonts(pdf, font_path)
  rescue StandardError => e
    if defined?(Rails)
      Rails.logger.warn("Font registration failed, using Helvetica: " \
                        "#{e.message}")
    end
    @font_family = "Helvetica"
  end

  def register_app_fonts(pdf, font_path)
    # Register DejaVu Sans font family from app assets
    font_variants = {
      normal: font_path.join("DejaVuSans.ttf"),
      bold: font_path.join("DejaVuSans-Bold.ttf"),
      italic: font_path.join("DejaVuSans-Oblique.ttf"),
      bold_italic: font_path.join("DejaVuSans-BoldOblique.ttf")
    }

    # Only register variants that actually exist
    available_fonts = {}
    font_variants.each do |variant, font_file|
      available_fonts[variant] = font_file.to_s if File.exist?(font_file)
    end

    unless available_fonts[:normal]
      raise("DejaVuSans.ttf not found in #{font_path}")
    end

    pdf.font_families.update("DejaVu Sans" => available_fonts)
    @font_family = "DejaVu Sans"
  end

  def font_family
    @font_family || "Helvetica"
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

# frozen_string_literal: true

require "rqrcode"

# Represents a QR code field with a label
class QRCodeField
  attr_reader :label, :url

  def initialize(label, url)
    @label = label
    @url = url
  end

  # Renders the QR code with label underneath
  def render(pdf, x_coord, y_coord, size = 0.75.in)
    return if url.nil? || url.to_s.strip.empty?

    temp_image = nil
    begin
      temp_image = generate_qr_image
      render_qr_code(pdf, temp_image.path, x_coord, y_coord, size)
      render_label_if_present(pdf, x_coord, y_coord, size)
    rescue StandardError => e
      handle_qr_generation_error(pdf, e, x_coord, y_coord, size)
    ensure
      cleanup_temp_file(temp_image)
    end
  end

  private

  def generate_qr_image
    qr_code = RQRCode::QRCode.new(url)
    png_data = create_png_data(qr_code)
    create_temp_image_file(png_data)
  end

  def create_png_data(qr_code)
    qr_code.as_png(
      bit_depth: 1,
      border_modules: 1,
      color_mode: ChunkyPNG::COLOR_GRAYSCALE,
      color: "black",
      fill: "white",
      module_px_size: 4
    )
  end

  def create_temp_image_file(png_data)
    temp_image = Tempfile.new(["qr", ".png"])
    temp_image.binmode
    temp_image.write(png_data.to_s)
    temp_image.close
    temp_image
  end

  def render_qr_code(pdf, image_path, x_coord, y_coord, size)
    pdf.image(image_path, at: [x_coord, y_coord], width: size, height: size)
  end

  def render_label_if_present(pdf, x_coord, y_coord, size)
    return unless label_should_be_rendered?

    label_position = calculate_label_position(pdf, x_coord, y_coord, size)
    draw_centered_label(pdf, label_position)
  end

  def label_should_be_rendered?
    label && !label.strip.empty?
  end

  def calculate_label_position(pdf, x_coord, y_coord, size)
    label_y = y_coord - size - 0.05.in
    width = pdf.width_of(label, size: 8)
    label_x = x_coord + size / 2 - width / 2

    {
      x: label_x,
      y: label_y,
      width: width
    }
  end

  def draw_centered_label(pdf, position)
    pdf.bounding_box([position[:x], position[:y]],
                     width: position[:width],
                     height: 0.15.in) do
      pdf.text(label, size: 8, align: :center, valign: :top)
    end
  end

  def handle_qr_generation_error(pdf, error, x_coord, y_coord, size)
    log_error_if_rails_available(error)
    render_fallback_text(pdf, x_coord, y_coord, size)
  end

  def log_error_if_rails_available(error)
    return unless defined?(Rails)

    Rails.logger.warn("QR code generation failed: #{error.message}")
  end

  def render_fallback_text(pdf, x_coord, y_coord, size)
    pdf.bounding_box([x_coord, y_coord], width: size, height: size) do
      pdf.text("QR: #{label}", size: 8, align: :center, valign: :center)
    end
  end

  def cleanup_temp_file(temp_image)
    temp_image&.unlink
  end
end

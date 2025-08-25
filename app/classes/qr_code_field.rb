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
  def render(pdf, x, y, size = 0.75.in)
    return if url.nil? || url.to_s.strip.empty?

    begin
      # Generate QR code
      qr_code = RQRCode::QRCode.new(url)

      # Render QR code as PNG data
      png_data = qr_code.as_png(
        bit_depth: 1,
        border_modules: 1,
        color_mode: ChunkyPNG::COLOR_GRAYSCALE,
        color: "black",
        fill: "white",
        module_px_size: 4
      )

      # Create temporary image from PNG data
      temp_image = Tempfile.new(["qr", ".png"])
      temp_image.binmode
      temp_image.write(png_data.to_s)
      temp_image.close

      # Render the QR code image
      pdf.image(temp_image.path, at: [x, y], width: size, height: size)

      # Render the label below the QR code
      if label && !label.strip.empty?
        label_y = y - size - 0.05.in
        pdf.bounding_box([x, label_y], width: size, height: 0.15.in) do
          pdf.text(label, size: 8, align: :center, valign: :top)
        end
      end
    rescue StandardError => e
      # Fallback: render label as text if QR generation fails
      if defined?(Rails)
        Rails.logger.warn("QR code generation failed: #{e.message}")
      end
      pdf.bounding_box([x, y], width: size, height: size) do
        pdf.text("QR: #{label}", size: 8, align: :center, valign: :center)
      end
    ensure
      temp_image&.unlink # Clean up temp file
    end
  end

  # Calculate total height needed (QR code + label)
  def height(size = 0.75.in)
    label_height = label && !label.strip.empty? ? 0.2.in : 0
    size + label_height
  end
end

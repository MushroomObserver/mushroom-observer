# frozen_string_literal: true

require("test_helper")
require "prawn/measurement_extensions"

class QRCodeFieldTest < UnitTestCase
  def test_error_case
    qrcf = ObservationLabels::QRCodeField.new("Home Page", 1.234)
    pdf = Prawn::Document.new(
      page_size: [10.in, 10.in],
      margin: 0
    )
    log_contents = with_captured_logger do
      qrcf.render(pdf, 0, 0, 5.in)
    end

    assert_match(/QR code generation failed: .+/, log_contents)
  end
end

# frozen_string_literal: true

require("test_helper")
require "prawn/measurement_extensions"

class QRCodeFieldTest < UnitTestCase
  def test_error_case
    qrcf = QRCodeField.new("Home Page", MO.http_domain)
    pdf = Prawn::Document.new(
      page_size: [0, 0],
      margin: 0
    )
    qrcf.render(pdf, 0, 0, 0)
  end
end

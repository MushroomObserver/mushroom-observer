# frozen_string_literal: true

# Form for scanning QR codes
class Components::QRReaderForm < Components::ApplicationForm
  def view_template
    text_field(:code, label: :app_qrcode.t,
                      data: { qr_reader_target: "input",
                              action: "qr-reader#handleInput" })
  end
end

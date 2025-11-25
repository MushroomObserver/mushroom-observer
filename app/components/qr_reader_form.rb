# frozen_string_literal: true

# Form for scanning QR codes
class Components::QRReaderForm < Components::ApplicationForm
  def initialize(model, **options)
    options[:id] ||= "qr_reader_form"
    options[:data] = { controller: "qr-reader" }.merge(options[:data] || {})
    super(model, **options) # rubocop:disable Style/SuperArguments
  end

  def view_template
    text_field(:code, label: :app_qrcode.t,
                      data: { qr_reader_target: "input",
                              action: "qr-reader#handleInput" })
  end
end

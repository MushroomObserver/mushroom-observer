# frozen_string_literal: true

# Form for scanning QR codes. Rendered by
# `Views::Controllers::FieldSlips::QRReader::New` and submitted to
# `FieldSlips::QRReaderController#create`.
module Views::Controllers::FieldSlips::QRReader
  class Form < ::Components::ApplicationForm
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

    def form_action
      url_for(controller: "field_slips/qr_reader", action: :create,
              only_path: true)
    end
  end
end

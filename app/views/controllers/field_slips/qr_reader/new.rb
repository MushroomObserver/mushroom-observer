# frozen_string_literal: true

# Action template for `FieldSlips::QRReaderController#new` — the
# "scan a QR code to find a field slip" landing page. Just a one-
# liner intro paragraph above the `Views::Controllers::FieldSlips::QRReader::Form`.
#
# Replaces `app/views/controllers/field_slips/qr_reader/new.erb`.
module Views::Controllers::FieldSlips::QRReader
  class New < Views::FullPageBase
    def view_template
      # `.t` runs the translation through MO's textile pipeline,
      # which turns the `"MO Field Slips":<url>` syntax into a real
      # `<a href>` — emit raw so the link survives.
      p { trusted_html(:field_slip_qr_intro.t) }
      render(Form.new(FieldSlip.new))
    end
  end
end

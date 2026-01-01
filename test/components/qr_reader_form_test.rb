# frozen_string_literal: true

require "test_helper"

class QRReaderFormTest < ComponentTestCase

  def setup
    @model = FieldSlip.new
    @html = render_form
  end

  def test_renders_qr_code_field
    assert_html(@html, "body", text: :app_qrcode.l)
    assert_html(@html, "input[data-qr-reader-target='input']")
    assert_html(@html, "input[data-action='qr-reader#handleInput']")
  end

  def test_form_has_form_control_class
    assert_html(@html, ".form-control")
  end

  def test_form_has_default_id_and_data_controller
    assert_html(@html, "form#qr_reader_form")
    assert_html(@html, "form[data-controller='qr-reader']")
  end

  private

  def render_form
    form = Components::QRReaderForm.new(@model, action: "/test_action")
    render(form)
  end
end

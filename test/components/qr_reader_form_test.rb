# frozen_string_literal: true

require "test_helper"

class QRReaderFormTest < UnitTestCase
  include ComponentTestHelper

  def setup
    @model = FieldSlip.new
    controller.request = ActionDispatch::TestRequest.create
  end

  def test_renders_qr_code_field
    form = render_form

    assert_includes(form, :app_qrcode.t)
    assert_includes(form, "data-qr-reader-target=\"input\"")
    assert_includes(form, "data-action=\"qr-reader#handleInput\"")
  end

  def test_form_has_form_control_class
    form = render_form

    assert_includes(form, "form-control")
  end

  private

  def render_form
    form = Components::QRReaderForm.new(
      @model,
      action: "/test_action",
      id: "qr_reader_form"
    )
    render(form)
  end
end

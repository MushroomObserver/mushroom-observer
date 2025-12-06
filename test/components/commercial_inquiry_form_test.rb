# frozen_string_literal: true

require "test_helper"

class CommercialInquiryFormTest < UnitTestCase
  include ComponentTestHelper

  def setup
    super
    @model = FormObject::CommercialInquiry.new
    @image = images(:commercial_inquiry_image)
    @user = users(:rolf)
    @message = "Test message"
    controller.request = ActionDispatch::TestRequest.create
    @html = render_form
  end

  def test_renders_form_with_image_preview
    assert_html(@html, "img")
  end

  def test_renders_form_with_message_field
    expected = :commercial_inquiry_header.tp(
      user: @image.user.legal_name
    ).as_displayed
    assert_html(@html, "body", text: expected)
    assert_html(@html, "textarea[name='commercial_inquiry[message]']")
    assert_html(@html, "textarea[rows='10']")
    assert_includes(@html, @message)
  end

  def test_renders_submit_button
    assert_html(@html, "input[type='submit'][value='#{:SEND.l}']")
    assert_html(@html, ".center-block")
  end

  private

  def render_form
    form = Components::CommercialInquiryForm.new(
      @model,
      image: @image,
      user: @user,
      message: @message
    )
    # Stub url_for to avoid routing errors in test environment
    form.stub(:url_for, "/test_action") do
      render(form)
    end
  end
end

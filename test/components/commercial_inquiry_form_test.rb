# frozen_string_literal: true

require "test_helper"

class CommercialInquiryFormTest < ComponentTestCase

  def setup
    super
    @model = FormObject::CommercialInquiry.new
    @image = images(:commercial_inquiry_image)
    @user = users(:rolf)
    @message = "Test message"
    @html = render_form
  end

  def test_renders_form_with_image_preview
    assert_html(@html, "img")
  end

  def test_renders_form_with_user_label
    bold_user = "**#{@image.user.legal_name}**"
    expected = :commercial_inquiry_header.t(user: bold_user).as_displayed
    assert_html(@html, "p", text: expected)
    assert_html(@html, "p b", text: @image.user.legal_name)
  end

  def test_renders_form_with_message_field
    expected_label = "#{:ask_user_question_message.t}:"
    assert_html(@html, "body", text: expected_label)
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

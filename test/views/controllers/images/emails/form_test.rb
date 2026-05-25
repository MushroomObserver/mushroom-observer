# frozen_string_literal: true

require("test_helper")

module Views::Controllers::Images::Emails
  class FormTest < ComponentTestCase
    def setup
      super
      @model = FormObject::EmailRequest.new
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
      assert_html(@html, "label[for='email_message']",
                  text: "#{:ask_user_question_message.t}:")
      assert_html(@html, "textarea[name='email[message]'][rows='10']",
                  text: @message)
    end

    def test_renders_submit_button
      assert_html(@html, "input[type='submit'][value='#{:SEND.l}']")
      assert_html(@html, ".center-block")
    end

    private

    def render_form
      form = Form.new(@model, image: @image, user: @user, message: @message)
      # Stub url_for to avoid routing errors in test environment
      form.stub(:url_for, "/test_action") { render(form) }
    end
  end
end

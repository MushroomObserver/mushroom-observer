# frozen_string_literal: true

require("test_helper")

module Views::Controllers::Users::Emails
  class FormTest < ComponentTestCase
    def setup
      super
      @model = FormObject::UserQuestion.new
      @target = users(:mary)
      @subject = "Test subject"
      @message = "Test message"
      @html = render_form
    end

    def test_renders_form_with_label
      expected =
        :ask_user_question_label.t(user: @target.legal_name).as_displayed
      assert_html(@html, "p", text: expected)
    end

    def test_renders_form_with_subject_field
      assert_html(@html, "label[for='user_question_subject']",
                  text: :ask_user_question_subject.l)
      assert_html(@html, "input[name='user_question[subject]'][size='70']")
      assert_includes(@html, @subject)
    end

    def test_renders_form_with_message_field
      assert_html(@html, "label[for='user_question_message']",
                  text: :ask_user_question_message.l)
      assert_html(@html,
                  "textarea[name='user_question[message]'][rows='10']")
      assert_includes(@html, @message)
    end

    def test_renders_submit_button
      assert_html(@html, "button[type='submit']", text: :send.ti)
      assert_html(@html, ".center-block")
    end

    private

    def render_form
      form = Form.new(@model,
                      target: @target,
                      subject: @subject,
                      message: @message)
      # Stub url_for to avoid routing errors in test environment
      form.stub(:url_for, "/test_action") do
        render(form)
      end
    end
  end
end

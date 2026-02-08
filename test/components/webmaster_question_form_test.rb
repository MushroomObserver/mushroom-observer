# frozen_string_literal: true

require "test_helper"

class WebmasterQuestionFormTest < ComponentTestCase
  def setup
    super
    @user_email = "test@example.com"
    @message = "My question"
    @html = render_form(reply_to: @user_email, message: @message)
  end

  def test_renders_form_with_help_note
    assert_html(@html, "body", text: :ask_webmaster_note.tp.as_displayed)
  end

  def test_renders_form_with_email_field
    assert_html(@html, "body", text: :ask_webmaster_your_email.l)
    assert_html(@html, "input[name='email[reply_to]']")
    assert_html(@html, "input[size='60']")
    assert_includes(@html, @user_email)
  end

  def test_renders_form_with_question_field
    assert_html(@html, "body", text: :ask_webmaster_question.l)
    assert_html(@html, "textarea[name='email[message]']")
    assert_html(@html, "textarea[rows='10']")
    assert_includes(@html, @message)
  end

  def test_renders_submit_button
    assert_html(@html, "input[type='submit'][value='#{:SEND.l}']")
    assert_html(@html, ".center-block")
  end

  private

  def render_form(reply_to: nil, message: nil, email_error: false)
    form = Components::WebmasterQuestionForm.new(
      reply_to: reply_to,
      message: message,
      email_error: email_error
    )
    # Stub url_for to avoid routing errors in test environment
    form.stub(:url_for, "/test_action") do
      render(form)
    end
  end
end

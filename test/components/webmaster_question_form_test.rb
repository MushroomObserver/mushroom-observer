# frozen_string_literal: true

require "test_helper"

class WebmasterQuestionFormTest < UnitTestCase
  include ComponentTestHelper

  def setup
    super
    @email = FormObject::WebmasterQuestion.new
    @user_email = "test@example.com"
    @content = "My question"
    controller.request = ActionDispatch::TestRequest.create
    @html = render_form
  end

  def test_renders_form_with_help_note
    assert_html(@html, "body", text: :ask_webmaster_note.tp.as_displayed)
  end

  def test_renders_form_with_email_field
    assert_html(@html, "body", text: :ask_webmaster_your_email.l)
    assert_html(@html, "input[name='webmaster_question[user][email]']")
    assert_html(@html, "input[size='60']")
    assert_includes(@html, @user_email)
  end

  def test_renders_form_with_question_field
    assert_html(@html, "body", text: :ask_webmaster_question.l)
    assert_html(@html, "textarea[name='webmaster_question[question][content]']")
    assert_html(@html, "textarea[rows='10']")
    assert_includes(@html, @content)
  end

  def test_renders_submit_button
    assert_html(@html, "input[type='submit'][value='#{:SEND.l}']")
    assert_html(@html, ".center-block")
  end

  private

  def render_form
    form = Components::WebmasterQuestionForm.new(
      @email,
      email: @user_email,
      content: @content
    )
    # Stub url_for to avoid routing errors in test environment
    form.stub(:url_for, "/test_action") do
      render(form)
    end
  end
end

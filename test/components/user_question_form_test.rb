# frozen_string_literal: true

require "test_helper"

class UserQuestionFormTest < UnitTestCase
  include ComponentTestHelper

  def setup
    super
    @model = FormObject::UserQuestion.new
    @target = users(:mary)
    @subject = "Test subject"
    @message = "Test message"
    controller.request = ActionDispatch::TestRequest.create
    @html = render_form
  end

  def test_renders_form_with_label
    expected = :ask_user_question_label.t(user: @target.legal_name).as_displayed
    assert_html(@html, "body", text: expected)
  end

  def test_renders_form_with_subject_field
    assert_html(@html, "body", text: :ask_user_question_subject.l)
    assert_html(@html, "input[name='user_question[subject]']")
    assert_html(@html, "input[size='70']")
    assert_includes(@html, @subject)
  end

  def test_renders_form_with_message_field
    assert_html(@html, "body", text: :ask_user_question_message.l)
    assert_html(@html, "textarea[name='user_question[message]']")
    assert_html(@html, "textarea[rows='10']")
    assert_includes(@html, @message)
  end

  def test_renders_submit_button
    assert_html(@html, "input[type='submit'][value='#{:SEND.l}']")
    assert_html(@html, ".center-block")
  end

  private

  def render_form
    form = Components::UserQuestionForm.new(
      @model,
      target: @target,
      subject: @subject,
      message: @message
    )
    # Stub url_for to avoid routing errors in test environment
    form.stub(:url_for, "/test_action") do
      render(form)
    end
  end
end

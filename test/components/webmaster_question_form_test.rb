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
  end

  def test_renders_form_with_help_note
    form = render_form

    assert_includes(form, :ask_webmaster_note.tp)
  end

  def test_renders_form_with_email_field
    form = render_form

    assert_includes(form, :ask_webmaster_your_email.t)
    assert_includes(form, 'name="webmaster_question[user][email]"')
    assert_includes(form, 'size="60"')
    assert_includes(form, @user_email)
  end

  def test_renders_form_with_question_field
    form = render_form

    assert_includes(form, :ask_webmaster_question.t)
    assert_includes(form, 'name="webmaster_question[question][content]"')
    assert_includes(form, "rows=\"10\"")
    assert_includes(form, @content)
  end

  def test_renders_submit_button
    form = render_form

    assert_includes(form, :SEND.l)
    assert_includes(form, "center-block")
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

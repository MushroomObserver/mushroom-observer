# frozen_string_literal: true

require "test_helper"

class ObserverQuestionFormTest < UnitTestCase
  include ComponentTestHelper

  def setup
    super
    @model = FormObject::ObserverQuestion.new
    @observation = observations(:minimal_unknown_obs)
    @message = "Where did you find this?"
    controller.request = ActionDispatch::TestRequest.create
    @html = render_form
  end

  def test_renders_form_with_user_label
    bold_user = "**#{@observation.user.legal_name}**"
    expected = :ask_observation_question_label.t(user: bold_user).as_displayed
    assert_html(@html, "p", text: expected)
    assert_html(@html, "p b", text: @observation.user.legal_name)
  end

  def test_renders_form_with_message_field
    expected_label = "#{:ask_user_question_message.t}:"
    assert_html(@html, "body", text: expected_label)
    assert_html(@html, "textarea[name='observer_question[message]']")
    assert_html(@html, "textarea[rows='6']")
    assert_includes(@html, @message)
  end

  def test_renders_submit_button
    assert_html(@html, "input[type='submit'][value='#{:SEND.l}']")
    assert_html(@html, ".center-block")
  end

  private

  def render_form
    form = Components::ObserverQuestionForm.new(
      @model,
      observation: @observation,
      message: @message
    )
    form.stub(:url_for, "/test_action") do
      render(form)
    end
  end
end

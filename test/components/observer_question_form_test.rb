# frozen_string_literal: true

require "test_helper"

class ObserverQuestionFormTest < UnitTestCase
  include ComponentTestHelper

  def setup
    super
    @observation = observations(:minimal_unknown_obs)
    @message = "My question about this observation"
    controller.request = ActionDispatch::TestRequest.create
    @html = render_form
  end

  def test_renders_form_with_label
    label_text = :ask_observation_question_label.tp(
      user: @observation.user.legal_name
    ).as_displayed
    assert_html(@html, "body", text: label_text)
  end

  def test_renders_form_with_message_field
    assert_html(@html, "textarea[name='question[message]']")
    assert_html(@html, "textarea[rows='6']")
  end

  def test_renders_form_with_message_value
    assert_includes(@html, @message)
  end

  def test_renders_submit_button
    assert_html(@html, "input[type='submit'][value='#{:SEND.l}']")
    assert_html(@html, ".center-block")
  end

  def test_renders_form_action
    assert_includes(@html, "/observations/#{@observation.id}/emails")
  end

  private

  def render_form
    form = Components::ObserverQuestionForm.new(
      observation: @observation,
      message: @message
    )
    render(form)
  end
end

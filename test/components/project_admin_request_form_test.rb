# frozen_string_literal: true

require "test_helper"

class ProjectAdminRequestFormTest < UnitTestCase
  include ComponentTestHelper

  def setup
    @model = FormObject::ProjectAdminRequest.new
    controller.request = ActionDispatch::TestRequest.create
    @html = render_form
  end

  def test_renders_form_with_subject_field
    assert_html(@html, "body", text: :request_subject.l)
    assert_html(@html, "input[name='email[subject]']")
    assert_html(@html, "input[data-autofocus]")
  end

  def test_renders_form_with_content_field
    assert_html(@html, "body", text: :request_message.l)
    assert_html(@html, "textarea[name='email[content]']")
    assert_html(@html, "textarea[rows='5']")
  end

  def test_renders_submit_button
    assert_html(@html, "input[type='submit'][value='#{:SEND.l}']")
    assert_html(@html, ".btn.btn-default")
    assert_html(@html, ".center-block.my-3")
  end

  def test_renders_note_text
    displayed = @html.as_displayed

    assert_includes(displayed, "Enter your request below")
    assert_includes(displayed, "project admins")
  end

  private

  def render_form
    form = Components::ProjectAdminRequestForm.new(
      @model,
      action: "/test_action",
      id: "project_admin_request_form"
    )
    render(form)
  end
end

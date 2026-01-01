# frozen_string_literal: true

require "test_helper"

class ProjectAdminRequestFormTest < ComponentTestCase

  def setup
    super
    @model = FormObject::ProjectAdminRequest.new
    @project = projects(:eol_project)
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
    render(Components::ProjectAdminRequestForm.new(@model, project: @project))
  end
end

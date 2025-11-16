# frozen_string_literal: true

require "test_helper"

class ProjectAdminRequestFormTest < UnitTestCase
  include ComponentTestHelper

  # Test model that includes necessary ActiveModel modules
  class TestEmail
    include ActiveModel::Model
    include ActiveModel::Attributes

    attribute :subject, :string
    attribute :content, :string

    def persisted?
      false
    end
  end

  def setup
    @model = TestEmail.new
    controller.request = ActionDispatch::TestRequest.create
  end

  def test_renders_form_with_subject_field
    form = render_form

    assert_includes(form, :request_subject.t)
    assert_includes(form, 'name="email[subject]"')
    assert_includes(form, "data-autofocus")
  end

  def test_renders_form_with_content_field
    form = render_form

    assert_includes(form, :request_message.t)
    assert_includes(form, 'name="email[content]"')
    assert_includes(form, "rows=\"5\"")
  end

  def test_renders_submit_button
    form = render_form

    assert_includes(form, :SEND.l)
    assert_includes(form, "btn btn-default")
    assert_includes(form, "center-block my-3")
  end

  def test_renders_note_text
    form = render_form
    displayed = form.as_displayed

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

# frozen_string_literal: true

require "test_helper"

class EmailNewPasswordFormTest < UnitTestCase
  include ComponentTestHelper

  def setup
    @user = User.new

    # Set up controller request context for form URL generation
    controller.request = ActionDispatch::TestRequest.create
  end

  def test_renders_form_with_login_field
    form = render_form

    assert_includes(form, "form-group")
    assert_includes(form, :login_user.t)
    assert_includes(form, 'name="new_user[login]"')
    assert_includes(form, 'type="text"')
    assert_includes(form, "mt-3")
    assert_includes(form, "data-autofocus")
  end

  def test_renders_submit_button
    form = render_form

    assert_includes(form, :SEND.l)
    assert_includes(form, "btn btn-default")
    assert_includes(form, "center-block my-3")
    assert_includes(form, "data-turbo-submits-with")
  end

  def test_form_has_correct_attributes
    form = render_form

    assert_includes(form, 'action="/test_form_path"')
    assert_includes(form, 'method="post"')
  end

  def test_component_vs_erb_html
    skip("HTML comparison - enable puts statements to see output")

    # Component version
    component_html = render_form

    # ERB version (what the old form would generate)
    erb_html = render_erb_version

    # puts "\n\n=== COMPONENT HTML ==="
    # puts component_html
    # puts "\n=== ERB HTML ==="
    # puts erb_html
    # puts "\n==================\n\n"

    # Both should work, but HTML may differ slightly
    assert(component_html.present?)
    assert(erb_html.present?)
  end

  private

  def render_form
    form = Components::EmailNewPasswordForm.new(
      @user,
      action: "/test_form_path",
      id: "account_email_new_password_form"
    )
    render(form)
  end

  def render_erb_version
    view_context.form_with(
      scope: :new_user,
      model: @user,
      url: "/test_form_path",
      id: "account_email_new_password_form"
    ) do |f|
      view_context.text_field_with_label(
        form: f,
        field: :login,
        label: "#{:login_user.t}:",
        class: "mt-3",
        data: { autofocus: true }
      ) +
        view_context.submit_button(form: f, button: :SEND.l, center: true)
    end
  end
end

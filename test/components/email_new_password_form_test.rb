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

  private

  def render_form
    form = Components::EmailNewPasswordForm.new(
      @user,
      action: "/test_form_path",
      id: "account_email_new_password_form"
    )
    render(form)
  end
end

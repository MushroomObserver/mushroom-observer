# frozen_string_literal: true

require "test_helper"

class LoginFormTest < UnitTestCase
  include ComponentTestHelper

  def setup
    @model = User.new
    controller.request = ActionDispatch::TestRequest.create
  end

  def test_renders_form_with_login_field
    form = render_form

    assert_includes(form, :login_user.t)
    assert_includes(form, 'name="user[login]"')
    assert_includes(form, "data-autofocus")
  end

  def test_renders_form_with_password_field
    form = render_form

    assert_includes(form, :login_password.t)
    assert_includes(form, 'name="user[password]"')
    assert_includes(form, 'type="password"')
  end

  def test_renders_remember_me_checkbox
    form = render_form

    assert_includes(form, :login_remember_me.t)
    assert_includes(form, 'name="user[remember_me]"')
    assert_includes(form, 'type="checkbox"')
  end

  def test_renders_submit_button
    form = render_form

    assert_includes(form, :login_login.l)
    assert_includes(form, "btn btn-default")
    assert_includes(form, "center-block my-3")
  end

  def test_renders_help_text
    form = render_form

    assert_includes(form, :login_having_problems.tp)
  end

  private

  def render_form
    form = Components::LoginForm.new(
      @model,
      action: "/test_action",
      id: "login_form"
    )
    render(form)
  end
end

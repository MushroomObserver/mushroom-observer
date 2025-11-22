# frozen_string_literal: true

require "test_helper"

class LoginFormTest < UnitTestCase
  include ComponentTestHelper

  def setup
    @model = FormObject::Login.new(login: "testuser", remember_me: true)
    controller.request = ActionDispatch::TestRequest.create
    @html = render_form
  end

  def test_renders_form_with_login_field
    assert_includes(@html, :login_user.t)
    assert_html(@html, "input[name='user[login]']")
    assert_html(@html, "input[data-autofocus]")
  end

  def test_renders_form_with_password_field
    assert_includes(@html, :login_password.t)
    assert_html(@html, "input[name='user[password]']")
    assert_html(@html, "input[type='password']")
  end

  def test_renders_remember_me_checkbox
    assert_includes(@html, :login_remember_me.t)
    assert_html(@html, "input[name='user[remember_me]']")
    assert_html(@html, "input[type='checkbox']")
  end

  def test_renders_submit_button
    assert_html(@html, "input[type='submit'][value='#{:login_login.l}']")
    assert_html(@html, ".btn.btn-default")
    assert_html(@html, ".center-block.my-3")
  end

  def test_renders_help_text
    assert_includes(@html, :login_having_problems.tp)
  end

  def test_renders_forgot_login_text
    assert_includes(@html, :login_forgot_password.tp)
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

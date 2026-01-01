# frozen_string_literal: true

require "test_helper"

class LoginFormTest < ComponentTestCase

  def setup
    @model = FormObject::Login.new(login: "testuser", remember_me: true)
    @html = render_form
  end

  def test_renders_form_with_login_field
    assert_html(@html, "body", text: :login_user.l)
    assert_html(@html, "input[name='user[login]']")
    assert_html(@html, "input[data-autofocus]")
  end

  def test_renders_form_with_password_field
    assert_html(@html, "body", text: :login_password.l)
    assert_html(@html, "input[name='user[password]']")
    assert_html(@html, "input[type='password']")
  end

  def test_renders_remember_me_checkbox
    assert_html(@html, "body", text: :login_remember_me.l)
    assert_html(@html, "input[name='user[remember_me]']")
    assert_html(@html, "input[type='checkbox']")
  end

  def test_renders_submit_button
    assert_html(@html, "input[type='submit'][value='#{:login_login.l}']")
    assert_html(@html, ".btn.btn-default")
    assert_html(@html, ".center-block.my-3")
  end

  def test_renders_help_text
    assert_html(@html, "body", text: :login_having_problems.tp.as_displayed)
  end

  def test_renders_forgot_login_text
    assert_html(@html, "body", text: :login_forgot_password.tp.as_displayed)
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

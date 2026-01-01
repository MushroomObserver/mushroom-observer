# frozen_string_literal: true

require "test_helper"

class EmailNewPasswordFormTest < ComponentTestCase

  def setup
    @user = User.new

    # Set up controller request context for form URL generation
    @html = render_form
  end

  def test_renders_form_with_login_field
    assert_html(@html, ".form-group")
    assert_html(@html, "body", text: :login_user.l)
    assert_html(@html, "input[name='new_user[login]']")
    assert_html(@html, "input[type='text']")
    assert_html(@html, ".mt-3")
    assert_html(@html, "input[data-autofocus]")
  end

  def test_renders_submit_button
    assert_html(@html, "input[type='submit'][value='#{:SEND.l}']")
    assert_html(@html, ".btn.btn-default")
    assert_html(@html, ".center-block.my-3")
    assert_html(@html, "input[data-turbo-submits-with]")
  end

  def test_form_has_correct_attributes
    assert_html(@html, "form[action='/test_form_path']")
    assert_html(@html, "form[method='post']")
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

# frozen_string_literal: true

require("test_helper")

module Views::Controllers::Account::Login
  class EmailNewPasswordFormTest < ComponentTestCase
    def setup
      super
      @user = User.new
      @html = render_form
    end

    def test_renders_form_with_login_field
      assert_html(@html, ".form-group")
      assert_html(@html, "label[for='new_user_login']",
                  text: :login_user.l)
      assert_html(@html,
                  "input[name='new_user[login]'][type='text']" \
                  "[data-autofocus]")
      assert_html(@html, ".mt-3")
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
      render(EmailNewPasswordForm.new(
               @user,
               action: "/test_form_path",
               id: "account_email_new_password_form"
             ))
    end
  end
end

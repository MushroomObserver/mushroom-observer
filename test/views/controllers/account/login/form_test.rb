# frozen_string_literal: true

require("test_helper")

module Views::Controllers::Account::Login
  class FormTest < ComponentTestCase
    def setup
      super
      @model = FormObject::Login.new(login: "testuser", remember_me: true)
      @html = render_form
    end

    def test_renders_form_with_login_field
      assert_html(@html, "label[for='user_login']", text: :login_user.l)
      assert_html(@html, "input[name='user[login]']")
      # With a pre-filled login, autofocus moves to the password
      # field (login_form: autofocus on login when blank, else on
      # password). The fixture has `login: "testuser"`.
      assert_html(@html,
                  "input[name='user[password]'][data-autofocus]")
    end

    def test_renders_form_with_password_field
      assert_html(@html, "label[for='user_password']",
                  text: :login_password.l)
      assert_html(@html, "input[name='user[password]'][type='password']")
    end

    def test_renders_remember_me_checkbox
      assert_html(@html, "label[for='user_remember_me']")
      assert_html(@html,
                  "input[name='user[remember_me]'][type='checkbox']")
      # Label text contains the localization string (along with the
      # nested checkbox HTML).
      remember_label =
        Nokogiri::HTML(@html).at_css("label[for='user_remember_me']").text
      assert_includes(remember_label, :login_remember_me.l)
    end

    def test_renders_submit_button
      assert_html(@html,
                  "input[type='submit'][value='#{:login_login.l}']")
      assert_html(@html, ".btn.btn-default")
      assert_html(@html, ".center-block.my-3")
    end

    def test_renders_help_text
      # Renders the webmaster-question link from the textile help.
      assert_html(@html, "a[href*='webmaster_questions']")
    end

    def test_renders_forgot_login_text
      # Renders the email-new-password link from the textile help.
      assert_html(@html, "a[href='/account/email_new_password']")
    end

    private

    def render_form
      render(Form.new(@model, action: "/test_action", id: "login_form"))
    end
  end
end

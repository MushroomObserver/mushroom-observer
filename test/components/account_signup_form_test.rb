# frozen_string_literal: true

require("test_helper")

class AccountSignupFormTest < ComponentTestCase
  def setup
    super
    @new_user = User.new(theme: MO.default_theme)
  end

  def test_renders_form_structure
    html = render_form

    # Form structure
    assert_html(html, "#account_signup_form")
    assert_html(html, "form[action='/account']")
    assert_html(html, "form[method='post']")

    # Login field
    assert_html(html, "input[name='new_user[login]'][type='text']")
    assert_includes(html, :signup_login.l)

    # Password fields
    assert_html(html, "input[name='new_user[password]'][type='password']")
    assert_includes(html, :signup_choose_password.l)
    assert_html(
      html,
      "input[name='new_user[password_confirmation]'][type='password']"
    )
    assert_includes(html, :signup_confirm_password.l)

    # Email fields
    assert_html(html, "input[name='new_user[email]'][type='text']")
    assert_includes(html, :signup_email_address.l)
    assert_html(html, "input[name='new_user[email_confirmation]'][type='text']")
    assert_includes(html, :signup_email_confirmation.l)

    # Email help text
    assert_includes(html, :signup_email_help.tp)
    assert_includes(html, :email_spam_notice.tp)

    # Name field
    assert_html(html, "input[name='new_user[name]'][type='text']")
    assert_includes(html, :signup_name.l)

    # Theme select
    assert_html(html, "select[name='new_user[theme]']")
    assert_includes(html, :signup_preferred_theme.l)

    # Submit button
    assert_html(html, "input[type='submit'][value='#{:signup_button.l}']")
  end

  def test_renders_theme_options
    html = render_form

    # Random theme option
    assert_includes(html, :theme_random.l)
    assert_includes(html, 'value="RANDOM"')

    # All available themes
    MO.themes.each do |theme|
      assert_includes(html, "value=\"#{theme}\"")
    end
  end

  def test_renders_with_existing_user_data
    @new_user.login = "testuser"
    @new_user.name = "Test User"
    @new_user.email = "test@example.com"
    @new_user.theme = "Agaricus"
    html = render_form

    assert_html(html, "input[name='new_user[login]'][value='testuser']")
    assert_html(html, "input[name='new_user[name]'][value='Test User']")
    assert_html(html, "input[name='new_user[email]'][value='test@example.com']")
    assert_html(html, "option[value='Agaricus'][selected]")
  end

  private

  def render_form
    render(Components::AccountSignupForm.new(@new_user))
  end
end

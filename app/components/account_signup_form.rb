# frozen_string_literal: true

# Form for creating a new user account (signup).
# Collects login, password, email, name, and theme preference.
class Components::AccountSignupForm < Components::ApplicationForm
  def initialize(model, **)
    super(model, method: :post, **)
  end

  def view_template
    super do
      render_login_field
      render_password_fields
      render_email_fields
      render_name_field
      render_theme_field
      submit(:signup_button.l, center: true)
    end
  end

  def form_action
    account_path
  end

  # Override Superform's key to use :new_user instead of :user
  # Controller expects params[:new_user]
  def key
    :new_user
  end

  private

  def render_login_field
    text_field(
      :login,
      label: "#{:signup_login.l}:",
      data: { autofocus: true }
    )
  end

  def render_password_fields
    password_field(:password, label: "#{:signup_choose_password.l}:")
    password_field(
      :password_confirmation,
      label: "#{:signup_confirm_password.l}:"
    )
  end

  def render_email_fields
    text_field(:email, label: "#{:signup_email_address.l}:")
    text_field(
      :email_confirmation,
      label: "#{:signup_email_confirmation.l}:"
    ) do |f|
      f.with_append { render_email_help }
    end
  end

  def render_email_help
    div(class: "help-note mr-3") do
      [:signup_email_help.tp, :email_spam_notice.tp].safe_join
    end
  end

  def render_name_field
    text_field(:name, label: "#{:signup_name.l}:")
  end

  def render_theme_field
    select_field(
      :theme,
      theme_options,
      label: "#{:signup_preferred_theme.l}:"
    )
  end

  def theme_options
    # Superform expects [value, display] format (opposite of Rails)
    [["NULL", :theme_random.l]] + MO.themes.map { |t| [t, t] }
  end
end

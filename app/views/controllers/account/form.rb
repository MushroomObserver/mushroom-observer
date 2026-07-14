# frozen_string_literal: true

module Views::Controllers::Account
  # Signup form for creating a new user account. Rendered by the
  # AccountController's `new.rb` (the top-level account
  # controller's only form-bearing page).
  # Collects login, password, email, name, and theme preference.
  class Form < ::Components::ApplicationForm
    def initialize(model, **)
      # Explicit id preserves `#account_signup_form` —
      # integration tests use it in `within(...)` blocks, and the
      # default Views/-namespaced derive_form_id would pick
      # `account_form` (loses the "signup" specificity).
      super(model, id: "account_signup_form", method: :post, **)
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
        label: :signup_login,
        data: { autofocus: true }
      )
    end

    def render_password_fields
      password_field(:password, label: :signup_choose_password)
      password_field(
        :password_confirmation,
        label: :signup_confirm_password
      )
    end

    def render_email_fields
      text_field(:email, label: :signup_email_address)
      text_field(
        :email_confirmation,
        label: :signup_email_confirmation
      ) do |f|
        f.with_append { render_email_help }
      end
    end

    def render_email_help
      Help(
        content: [:signup_email_help.tp, :email_spam_notice.tp].safe_join
      )
    end

    def render_name_field
      text_field(:name, label: :signup_name)
    end

    def render_theme_field
      select_field(
        :theme,
        theme_options,
        label: :signup_preferred_theme
      )
    end

    def theme_options
      # "RANDOM" is a sentinel value that triggers random theme
      # selection.
      [[:theme_random.l, "RANDOM"]] +
        MO.themes.map { |t| [t.to_sym.l, t] }
    end
  end
end

# frozen_string_literal: true

module Views::Controllers::Account::Login
  # Form for requesting a new password via email. Rendered by the
  # account/login controller's `email_new_password.html.erb`. Keeps
  # the descriptive name (sibling to `Login::Form`) since the login
  # controller has multiple form-bearing pages.
  class EmailNewPasswordForm < ::Components::ApplicationForm
    def view_template
      text_field(:login, label: "#{:login_user.t}:", wrap_class: "mt-3",
                         data: { autofocus: true })

      submit(:SEND.l, center: true)
    end

    # Override to use :new_user scope instead of :user
    def key
      :new_user
    end
  end
end

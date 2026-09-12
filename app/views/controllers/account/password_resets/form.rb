# frozen_string_literal: true

module Views::Controllers::Account::PasswordResets
  # Form for requesting a new password via email. Rendered by
  # `Account::PasswordResetsController#new`.
  class Form < ::Components::ApplicationForm
    def view_template
      text_field(:login, label: :login_user, wrap_class: "mt-3",
                         data: { autofocus: true })

      submit(:send.ti, center: true)
    end

    # Override to use :new_user scope instead of :user
    def key
      :new_user
    end
  end
end

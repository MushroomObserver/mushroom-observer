# frozen_string_literal: true

# Form for requesting a new password via email
class Components::EmailNewPasswordForm < Components::ApplicationForm
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

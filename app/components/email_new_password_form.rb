# frozen_string_literal: true

# Form for requesting a new password via email
class Components::EmailNewPasswordForm < Components::ApplicationForm
  def view_template
    text_field(:login, label: "#{:login_user.t}:", class_name: "mt-3",
                       data: { autofocus: true })

    submit(:SEND.l, class: "btn btn-default center-block my-3",
                    data: { turbo_submits_with: submits_text,
                            disable_with: :SEND.l })
  end

  # Override to use :new_user scope instead of :user
  def key
    :new_user
  end

  private

  def submits_text
    :SUBMITTING.l
  end
end

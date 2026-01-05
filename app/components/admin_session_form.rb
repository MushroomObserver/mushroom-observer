# frozen_string_literal: true

# Form for admins to switch to another user's account.
# Allows admins to impersonate users for debugging/support.
class Components::AdminSessionForm < Components::ApplicationForm
  def initialize(model, **)
    super(model, id: "admin_switch_users_form", **)
  end

  def view_template
    super do
      autocompleter_field(
        :id,
        type: :user,
        label: "#{:LOGIN_NAME.l}:",
        value: model.id,
        size: 42,
        autofocus: true
      )
      submit(:SUBMIT.l, center: true)
    end
  end

  def form_action
    admin_mode_path
  end

  protected

  def form_method
    "put"
  end
end

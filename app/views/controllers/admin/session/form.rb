# frozen_string_literal: true

module Views::Controllers::Admin::Session
  # Form for admins to switch to another user's account. Rendered by
  # the admin/session controller's `edit.rb`. Allows admins to
  # impersonate users for debugging/support.
  class Form < ::Components::ApplicationForm
    def initialize(model, **)
      super(model, id: "admin_switch_users_form", **)
    end

    def view_template
      super do
        autocompleter_field(
          :user,
          type: :user,
          label: :login_name.ti,
          value: model.user,
          size: 42,
          autofocus: true
        )
        submit(:submit.ti, center: true)
      end
    end

    def form_action
      admin_mode_path
    end
  end
end

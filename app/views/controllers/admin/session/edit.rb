# frozen_string_literal: true

module Views::Controllers::Admin::Session
  # Form for admins to switch to another user's account. Trivial
  # wrapper: sets the page title and renders the form component.
  class Edit < Views::FullPageBase
    prop :form, ::FormObject::AdminSession

    def view_template
      add_page_title(:app_switch_users.l)
      render(Form.new(@form))
    end
  end
end

# frozen_string_literal: true

module Views::Controllers::Herbaria
  # Action view for the edit herbarium form page.
  class Edit < Views::FullPageBase
    prop :herbarium, ::Herbarium
    prop :user, ::User
    # nil for non-admins -- set_up_herbarium_for_edit only computes
    # this `if in_admin_mode?`.
    prop :top_users, _Nilable(_Array(::User))

    def view_template
      add_edit_title(@herbarium)
      add_context_nav(::Tab::Herbarium::FormEdit.new(herbarium: @herbarium,
                                                     q_param: q_param))

      render(Views::Controllers::Herbaria::Form.new(
               @herbarium, user: @user, turbo: true,
                           location: @herbarium.location, top_users: @top_users
             ))
    end
  end
end

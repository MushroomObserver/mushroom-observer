# frozen_string_literal: true

# Form for adding a user to a group (admin only)
class Components::AddUserToGroupForm < Components::ApplicationForm
  def view_template
    text_field(:user_name,
               label: "#{:add_user_to_group_user.t}:",
               data: { autofocus: true })
    text_field(:group_name,
               label: "#{:add_user_to_group_group.t}:")
    submit(:ADD.t, center: true)
  end
end

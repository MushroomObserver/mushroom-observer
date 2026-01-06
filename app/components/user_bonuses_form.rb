# frozen_string_literal: true

# Form for editing user contribution bonuses (admin only).
# Allows admins to manually adjust user bonus points.
class Components::UserBonusesForm < Components::ApplicationForm
  def view_template
    super do
      div(class: "help-note mr-3") { :change_user_bonuses_help.tp }
      textarea_field(:val, value: model.formatted_bonuses, rows: 5,
                           class: "mt-3")
      submit(:SAVE_EDITS.l, center: true)
    end
  end

  def form_action
    admin_user_path(id: model.user_id)
  rescue NoMethodError
    # Fallback for tests where admin routes may not be available
    "/admin/users/#{model.user_id}"
  end
end

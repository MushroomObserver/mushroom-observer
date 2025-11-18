# frozen_string_literal: true

# Form for editing user contribution bonuses (admin only).
# Allows admins to manually adjust user bonus points.
class Components::UserBonusesForm < Components::ApplicationForm
  def initialize(model, val:, help_text:, **)
    @val = val
    @help_text = help_text
    super(model, **)
  end

  def view_template
    super do
      div(class: "help-note mr-3") { @help_text }
      textarea_field(:val, value: @val, rows: 5, class: "mt-3")
      submit(:SAVE_EDITS.l, center: true)
    end
  end

  def form_action
    view_context.admin_users_path
  end

  protected

  def form_method
    "patch"
  end
end

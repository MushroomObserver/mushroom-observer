# frozen_string_literal: true

# Inline form for adding members to a Project. Posts a list of user
# identifiers (textarea, newline-separated) to project_members_path
# via Turbo, so the surrounding members table re-renders without a
# full page reload.
#
# Pattern B: creates a FormObject internally so the view only needs
# to pass the `project:` kwarg. Shared shape lives in
# `Views::Controllers::Projects::TargetWidgetBase`.
class Views::Controllers::Projects::Members::AddForm <
      Views::Controllers::Projects::TargetWidgetBase
  def form_action
    project_members_path(project_id: @project.id)
  end

  private

  def dom_id = "project_members_widget"
  def form_object = FormObject::ProjectMembersAdd.new
  def field_name = :candidates
  def autocompleter_type = :user
  def label_key = :project_members_to_add_label
  def submit_key = :project_member_add
end

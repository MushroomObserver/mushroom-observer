# frozen_string_literal: true

# Inline form for adding target names to a Project. Posts a list
# of names (textarea, newline-separated) to
# `project_target_names_path` via Turbo, so the surrounding
# checklist re-renders without a full page reload.
#
# Pattern B: creates its own FormObject internally so the view
# only needs to pass the `project:` kwarg. Shared shape lives in
# `Components::ProjectTargetWidgetBase`.
class Components::ProjectTargetNamesWidget <
      Components::ProjectTargetWidgetBase
  def form_action
    project_target_names_path(project_id: @project.id)
  end

  private

  def dom_id = "target_names_widget"
  def form_object = FormObject::ProjectTargetNamesAdd.new
  def field_name = :names
  def autocompleter_type = :name
  def label_key = :project_target_names_to_add_label
  def submit_key = :project_target_name_add
end

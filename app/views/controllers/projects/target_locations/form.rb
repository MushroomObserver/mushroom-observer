# frozen_string_literal: true

# Inline form for adding target locations to a Project. Posts a
# list of location names (textarea, newline-separated) to
# `project_target_locations_path` via Turbo, so the surrounding
# locations table re-renders without a full page reload.
#
# Pattern B: creates its own FormObject internally so the view
# only needs to pass the `project:` kwarg. Shared shape lives in
# `Views::Controllers::Projects::TargetWidgetBase`.
class Views::Controllers::Projects::TargetLocations::Form <
      Views::Controllers::Projects::TargetWidgetBase
  def form_action
    project_target_locations_path(project_id: @project.id)
  end

  private

  def dom_id = "target_locations_widget"
  def form_object = FormObject::ProjectTargetLocationsAdd.new
  def field_name = :locations
  def autocompleter_type = :location
  def label_key = :project_target_locations_to_add_label
  def submit_key = :project_target_location_add
end

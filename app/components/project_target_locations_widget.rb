# frozen_string_literal: true

# Inline form for adding target locations to a Project. Posts a
# list of location names (textarea, newline-separated) to
# `project_target_locations_path` via Turbo, so the surrounding
# locations table re-renders without a full page reload.
#
# Pattern B: creates its own FormObject internally so the view
# only needs to pass the `project:` kwarg.
class Components::ProjectTargetLocationsWidget < Components::ApplicationForm
  # Optional positional model arg is accepted for ModalForm
  # compatibility (ignored) — see Pattern B in
  # .claude/phlex_style_guide.md.
  def initialize(_model = nil, project:, **)
    @project = project
    super(FormObject::ProjectTargetLocationsAdd.new,
          id: "target_locations_widget", local: false, **)
  end

  def around_template
    @attributes[:class] = "form-inline mb-3"
    super
  end

  def view_template
    super do
      autocompleter_field(
        :locations,
        type: :location,
        textarea: true,
        separator: "\n",
        label: "#{:LOCATIONS.t}:"
      )
      submit(:project_target_location_add.t, class: "ml-2 mt-2")
    end
  end

  def form_action
    project_target_locations_path(project_id: @project.id)
  end
end

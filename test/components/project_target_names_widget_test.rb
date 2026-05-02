# frozen_string_literal: true

require("test_helper")

class ProjectTargetNamesWidgetTest < ComponentTestCase
  def test_renders_form_with_correct_action_and_turbo
    project = projects(:rare_fungi_project)

    html = render_widget(project: project)

    # Form is the turbo-stream replace target — id matches the
    # surrounding `turbo_stream.replace("target_names_widget")`.
    expected_path = "/projects/#{project.id}/target_names"
    assert_html(
      html,
      "form#target_names_widget[action='#{expected_path}']" \
      "[method='post'][data-turbo='true']"
    )
    assert_html(html, "form.form-inline")
  end

  def test_renders_autocompleter_textarea_under_form_object_namespace
    project = projects(:rare_fungi_project)

    html = render_widget(project: project)

    assert_html(html, ".autocompleter")
    # Pattern B FormObject namespaces the textarea name under
    # `project_target_names_add`. The controller reads it via
    # `params.dig(:project_target_names_add, :names)`.
    assert_html(html, "textarea[name='project_target_names_add[names]']")
    assert_html(
      html,
      ".autocompleter[data-controller~='autocompleter--name']"
    )
    assert_includes(html, :project_target_names_to_add_label.l)
  end

  def test_renders_submit_button
    project = projects(:rare_fungi_project)

    html = render_widget(project: project)

    assert_html(
      html,
      "input[type='submit']" \
      "[value='#{:project_target_name_add.l}']"
    )
  end

  # The `project-target-widget` class is shared with the locations
  # widget and is the hook for `_form_elements.scss` to widen the
  # textarea inside the surrounding form-inline form (#4147).
  def test_form_carries_shared_widget_class
    project = projects(:rare_fungi_project)

    html = render_widget(project: project)

    assert_html(
      html,
      "form#target_names_widget.form-inline.project-target-widget"
    )
  end

  private

  def render_widget(project:)
    render(Components::ProjectTargetNamesWidget.new(project: project))
  end
end

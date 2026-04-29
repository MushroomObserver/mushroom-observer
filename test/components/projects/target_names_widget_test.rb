# frozen_string_literal: true

require("test_helper")

module Projects
  class TargetNamesWidgetTest < ComponentTestCase
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

    private

    def render_widget(project:)
      render(Components::Projects::TargetNamesWidget.new(project: project))
    end
  end
end

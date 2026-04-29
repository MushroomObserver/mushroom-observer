# frozen_string_literal: true

require("test_helper")

module Projects
  class TargetNamesWidgetTest < ComponentTestCase
    def test_renders_form_with_correct_action_and_turbo
      project = projects(:rare_fungi_project)

      html = render_widget(project: project)

      # Outer turbo-stream target.
      assert_html(html, "#target_names_widget")

      # Form posts to the target_names create endpoint with turbo enabled.
      expected_path = "/projects/#{project.id}/target_names"
      assert_html(
        html,
        "form[action='#{expected_path}']" \
        "[method='post'][data-turbo='true']"
      )
      # form-inline class preserved from the old ERB.
      assert_html(html, "form.form-inline")
    end

    def test_renders_autocompleter_textarea_for_names
      project = projects(:rare_fungi_project)

      html = render_widget(project: project)

      # Autocompleter wraps a textarea (textarea: true) named :names.
      assert_html(html, ".autocompleter")
      assert_html(html, "textarea[name='names']")
      # Stimulus controller for the name autocompleter.
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

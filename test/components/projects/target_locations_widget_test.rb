# frozen_string_literal: true

require("test_helper")

module Projects
  class TargetLocationsWidgetTest < ComponentTestCase
    def test_renders_form_with_correct_action_and_turbo
      project = projects(:rare_fungi_project)

      html = render_widget(project: project)

      assert_html(html, "#target_locations_widget")

      expected_path = "/projects/#{project.id}/target_locations"
      assert_html(
        html,
        "form[action='#{expected_path}']" \
        "[method='post'][data-turbo='true']"
      )
      assert_html(html, "form.form-inline")
    end

    def test_renders_autocompleter_textarea_for_locations
      project = projects(:rare_fungi_project)

      html = render_widget(project: project)

      assert_html(html, ".autocompleter")
      assert_html(html, "textarea[name='locations']")
      assert_html(
        html,
        ".autocompleter[data-controller~='autocompleter--location']"
      )
      assert_includes(html, :LOCATIONS.l)
    end

    def test_renders_submit_button
      project = projects(:rare_fungi_project)

      html = render_widget(project: project)

      assert_html(
        html,
        "input[type='submit']" \
        "[value='#{:project_target_location_add.l}']"
      )
    end

    private

    def render_widget(project:)
      render(Components::Projects::TargetLocationsWidget.new(project: project))
    end
  end
end

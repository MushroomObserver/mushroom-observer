# frozen_string_literal: true

require("test_helper")

module Views::Controllers::Projects::Members
  class AddFormTest < ComponentTestCase
    def test_renders_form_with_correct_action_and_turbo
      project = projects(:eol_project)

      html = render_widget(project: project)

      expected_path = "/projects/#{project.id}/members"
      assert_html(
        html,
        "form#project_members_widget[action='#{expected_path}']" \
        "[method='post'][data-turbo='true']"
      )
    end

    def test_renders_autocompleter_textarea_under_form_object_namespace
      project = projects(:eol_project)

      html = render_widget(project: project)

      assert_html(html, ".autocompleter")
      assert_html(
        html,
        "textarea[name='project_members_add[candidates]']"
      )
      assert_html(
        html,
        ".autocompleter[data-controller~='autocompleter--user']"
      )
      assert_includes(html, :project_members_to_add_label.l)
    end

    def test_renders_submit_button
      project = projects(:eol_project)

      html = render_widget(project: project)

      assert_html(html, "button[type='submit']",
                  text: :project_member_add.l)
    end

    # Same shared class as the Names/Locations widgets.
    def test_form_carries_shared_widget_class
      project = projects(:eol_project)

      html = render_widget(project: project)

      assert_html(
        html,
        "form#project_members_widget.project-target-widget"
      )
    end

    private

    def render_widget(project:)
      render(AddForm.new(project: project))
    end
  end
end

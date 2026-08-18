# frozen_string_literal: true

require("test_helper")

module Views::Controllers::Projects
  class ListItemTest < ComponentTestCase
    def setup
      super
      @user = users(:rolf)
    end

    def test_renders_project
      project = projects(:eol_project)
      html = render_item(project: project)

      # No `.list-group-item` wrapper — supplied by the caller.
      assert_no_html(html, "div.list-group-item")

      # Title link
      assert_html(html, "a[href*='projects/#{project.id}']")
      assert_html(html, "span.h4")

      # Meta row with user
      assert_includes(html, project.created_at.web_time)
    end

    def test_open_membership_badge
      project = projects(:eol_project)
      project.open_membership = true
      html = render_item(project: project)

      assert_html(html, "span.ml-4")
      assert_includes(html, :open.ti)
    end

    def test_closed_membership_no_badge
      project = projects(:eol_project)
      project.open_membership = false
      html = render_item(project: project)

      assert_no_html(html, "span.ml-4")
    end

    def test_no_manage_section_without_observation_context
      project = projects(:eol_project)
      html = render_item(project: project)

      assert_no_html(html, "form")
    end

    def test_remove_button
      project = projects(:eol_project)
      obs = observations(:coprinus_comatus_obs)
      html = render_item(project: project, observation: obs, remove: true)

      assert_html(
        html,
        "form[action='#{routes.observation_project_path(
          id: obs.id, project_id: project.id, commit: "remove"
        )}'] button"
      )
    end

    def test_add_button
      project = projects(:eol_project)
      obs = observations(:coprinus_comatus_obs)
      html = render_item(project: project, observation: obs, add: true)

      assert_html(
        html,
        "form[action='#{routes.observation_project_path(
          id: obs.id, project_id: project.id, commit: "add"
        )}'] button"
      )
    end

    def test_violation_warning
      project = projects(:eol_project)
      html = render_item(project: project, violation_kinds: [:date, :bbox])

      assert_includes(html, :form_observations_projects_kind_date.l)
      assert_includes(html, :form_observations_projects_kind_bbox.l)
    end

    def test_no_violation_warning_when_no_kinds
      project = projects(:eol_project)
      html = render_item(project: project, violation_kinds: [])

      assert_no_html(html, ".text-warning")
    end

    private

    def routes
      Rails.application.routes.url_helpers
    end

    def render_item(**)
      render(ListItem.new(**))
    end
  end
end

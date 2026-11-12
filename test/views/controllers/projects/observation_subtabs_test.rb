# frozen_string_literal: true

require("test_helper")

module Views::Controllers::Projects
  # Tests for the member-facing project observation sub-tabs
  # component -- Observations / Map / Images / Download, plus Field
  # Slips when the project has a field_slip_prefix and Violations
  # when it has constraints.
  class Views::Controllers::Projects::ObservationSubtabsTest <
    ComponentTestCase
    def test_renders_four_subtabs_without_field_slip_prefix
      project = projects(:empty_project) # no field_slip_prefix
      html = render_subtabs(project: project, current_subtab: "observations")

      assert_html(html, "ul.nav.nav-tabs#project_observation_subtabs")
      assert_html(
        html,
        "a[href='#{routes.observations_path(
          project: project.id, by: "thumbnail_quality"
        )}']",
        text: :observations.ti
      )
      assert_html(html, "a[href^='#{routes.map_observations_path}']")
      assert_html(
        html, "a[href^='#{routes.new_observations_download_path}']"
      )
      assert_no_html(
        html, "a[href='#{routes.field_slips_path(project: project.id)}']"
      )
    end

    def test_renders_field_slips_subtab_with_prefix
      project = projects(:eol_project) # field_slip_prefix: "EOL"
      html = render_subtabs(project: project, current_subtab: "field_slips")

      assert_html(
        html,
        "a.nav-link.active[href='#{routes.field_slips_path(
          project: project.id
        )}']",
        text: :field_slips.ti
      )
    end

    def test_observations_active_when_current
      project = projects(:eol_project)
      html = render_subtabs(project: project, current_subtab: "observations")

      assert_html(
        html,
        "a.nav-link.active[href='#{routes.observations_path(
          project: project.id, by: "thumbnail_quality"
        )}']"
      )
    end

    def test_map_active_when_current
      project = projects(:eol_project)
      html = render_subtabs(project: project, current_subtab: "map")

      assert_html(
        html, "a.nav-link.active[href^='#{routes.map_observations_path}']"
      )
    end

    def test_download_active_when_current
      project = projects(:eol_project)
      html = render_subtabs(project: project, current_subtab: "download")

      assert_html(
        html,
        "a.nav-link.active[href^='#{routes.new_observations_download_path}']"
      )
    end

    def test_renders_violations_subtab_with_constraints
      project = projects(:rare_fungi_project) # has targets -> constraints?
      html = render_subtabs(project: project, current_subtab: "violations")

      assert_html(
        html,
        "a.nav-link.active[href='#{routes.project_violations_path(
          project.id
        )}']",
        text: :constraint_violations.ti
      )
    end

    def test_no_violations_subtab_without_constraints
      project = projects(:eol_project) # no start/end date, location, targets
      html = render_subtabs(project: project, current_subtab: "observations")

      assert_no_html(
        html,
        "a[href='#{routes.project_violations_path(project.id)}']"
      )
    end

    private

    def routes
      Rails.application.routes.url_helpers
    end

    def render_subtabs(project:, current_subtab:)
      render(ObservationSubtabs.new(
               project: project, current_subtab: current_subtab
             ))
    end
  end
end

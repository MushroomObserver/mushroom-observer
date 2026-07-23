# frozen_string_literal: true

require("test_helper")

class Views::Controllers::Observations::Show::ProjectsPanelTest <
  ComponentTestCase
  def test_no_projects_renders_nothing
    obs = observations(:imageless_unvouchered_obs)
    assert(obs.projects.none?, "Need obs fixture obs without projects")

    html = render(panel_with(obs))

    assert_equal("", html)
  end

  def test_renders_panel_with_project_link
    obs = observations(:detailed_unknown_obs)
    project = obs.projects.first
    assert_not_nil(project, "Need obs fixture with at least one project")

    html = render(panel_with(obs))

    assert_html(html, "#observation_projects")
    assert_html(html, "a[href='#{routes.project_path(project.id)}']")
  end

  # No add/remove-membership affordance -- unlike SpeciesListsPanel,
  # there's no mechanism to add/remove an observation from a project
  # on this page.
  def test_renders_no_remove_or_add_controls
    obs = observations(:detailed_unknown_obs)

    html = render(panel_with(obs))

    assert_no_html(html, "form")
    assert_no_html(html, "button")
  end

  private

  def routes
    Rails.application.routes.url_helpers
  end

  def panel_with(obs)
    Views::Controllers::Observations::Show::ProjectsPanel.new(obs: obs)
  end
end

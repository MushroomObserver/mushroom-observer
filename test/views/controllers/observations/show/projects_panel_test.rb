# frozen_string_literal: true

require("test_helper")

class Views::Controllers::Observations::Show::ProjectsPanelTest <
  ComponentTestCase
  def test_no_projects_and_no_member_projects_renders_nothing
    obs = observations(:imageless_unvouchered_obs)
    user = users(:zero_user)
    assert(obs.projects.none?, "Need obs fixture obs without projects")
    assert(user.projects_member.none?,
           "Need user fixture who is a member of no projects")

    html = render(panel_with(obs, user))

    assert_equal("", html)
  end

  def test_no_projects_but_user_is_member_renders_add_link
    obs = observations(:imageless_unvouchered_obs)
    user = users(:rolf)
    assert(obs.projects.none?, "Need obs fixture obs without projects")
    assert(user.projects_member.any?,
           "Need user fixture who is a member of at least one project")

    html = render(panel_with(obs, user))

    assert_html(
      html,
      "a[href='#{routes.edit_observation_projects_path(obs.id)}']",
      text: :show_observation_add_to_project.l
    )
    assert_no_html(html, "ul")
  end

  def test_projects_renders_bare_heading_and_manage_link
    obs = observations(:detailed_unknown_obs)
    project = obs.projects.first
    assert_not_nil(project, "Need obs fixture with at least one project")

    html = render(panel_with(obs, users(:mary)))

    assert_html(html, "#observation_projects")
    assert_html(html, "a[href='#{routes.project_path(project.id)}']")
    assert_html(
      html,
      "a[href='#{routes.edit_observation_projects_path(obs.id)}']"
    )
  end

  def test_remove_button_shown_only_for_members
    obs = observations(:detailed_unknown_obs)
    project = obs.projects.first
    assert_not_nil(project, "Need obs fixture with at least one project")
    assert(project.member?(users(:mary)), "Need mary to be a project member")

    member_html = render(panel_with(obs, users(:mary)))
    form_selector = "form[action='#{routes.observation_project_path(
      id: obs.id, project_id: project.id, commit: "remove"
    )}']"
    assert_html(member_html, "#{form_selector} button svg.mo-icon-remove")

    non_member_html = render(panel_with(obs, users(:rolf)))
    assert_no_html(non_member_html, form_selector)
  end

  private

  def routes
    Rails.application.routes.url_helpers
  end

  def panel_with(obs, user = nil)
    Views::Controllers::Observations::Show::ProjectsPanel.new(
      obs: obs, user: user
    )
  end
end

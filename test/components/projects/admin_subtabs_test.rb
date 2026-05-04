# frozen_string_literal: true

require "test_helper"

# Tests for the project Admin sub-tabs component (issue #4148).
class Components::Projects::AdminSubtabsTest < ComponentTestCase
  def test_renders_three_subtabs
    project = projects(:eol_project)
    html = render_subtabs(project: project, current_subtab: "details")

    # Wrapping row + col-xs-12 ensures the sub-tabs claim a full row
    # so the next element doesn't float alongside them.
    assert_html(html, ".row #project_admin_subtabs")
    assert_html(html, "ul.nav.nav-tabs")
    assert_html(html, "a[href='/projects/#{project.id}/admin']",
                text: :show_project_admin_details_tab.l)
    assert_html(html, "a[href='/projects/#{project.id}/members']")
    assert_html(html, "a[href='/projects/#{project.id}/aliases']")
  end

  def test_details_active_when_current
    project = projects(:eol_project)
    html = render_subtabs(project: project, current_subtab: "details")

    assert_html(
      html,
      "a.nav-link.active[href='/projects/#{project.id}/admin']"
    )
  end

  def test_members_active_when_current
    project = projects(:eol_project)
    html = render_subtabs(project: project, current_subtab: "members")

    assert_html(
      html,
      "a.nav-link.active[href='/projects/#{project.id}/members']"
    )
  end

  def test_aliases_active_when_current
    project = projects(:eol_project)
    html = render_subtabs(project: project, current_subtab: "aliases")

    assert_html(
      html,
      "a.nav-link.active[href='/projects/#{project.id}/aliases']"
    )
  end

  def test_member_count_in_label
    project = projects(:eol_project)
    expected_count = project.user_group.users.count
    html = render_subtabs(project: project, current_subtab: "details")

    assert_includes(html, "#{expected_count} #{:MEMBERS.l}")
  end

  def test_alias_count_in_label
    project = projects(:eol_project)
    expected_count = project.aliases.length
    html = render_subtabs(project: project, current_subtab: "details")

    assert_includes(html, "#{expected_count} #{:PROJECT_ALIASES.l}")
  end

  private

  def render_subtabs(project:, current_subtab:)
    render(Components::Projects::AdminSubtabs.new(
             project: project, current_subtab: current_subtab
           ))
  end
end

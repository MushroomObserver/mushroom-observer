# frozen_string_literal: true

require "test_helper"

# Tests for ProjectBanner component structure and conditional rendering.
# This component now handles all project banner logic internally including
# banner image, title, location, date range, and tabs.
class ProjectBannerTest < ComponentTestCase
  def test_renders_basic_html_structure_with_banner_image
    project = projects(:albion_project)
    html = render_banner(project: project)

    # Outer row and container
    assert_html(html, ".row")
    assert_html(html, ".col-xs-12#project_banner")

    # Banner overlay positioning (only with images)
    assert_html(html, ".bottom-left.ml-3.mb-3.p-2")

    # Title heading structure with overlay styling
    assert_html(html, "h1.h3.banner-image-text")
  end

  def test_renders_basic_html_structure_without_banner_image
    project = projects(:empty_project)
    html = render_banner(project: project)

    # Outer row and container
    assert_html(html, ".row")
    assert_html(html, ".col-xs-12#project_banner")

    # No banner overlay positioning without images
    assert_no_html(html, ".bottom-left")

    # Title heading structure with regular page title styling
    assert_html(html, "h1.h3.page-title")
  end

  def test_title_id_is_consistent_across_pages
    html = render_banner

    assert_html(html, "h1#title")
    assert_no_html(html, "h1#banner_title")
  end

  def test_title_includes_id_badge
    project = projects(:eol_project)
    html = render_banner(project: project)

    assert_html(html, "h1#title .badge.badge-id")
  end

  def test_renders_banner_image_when_project_has_image
    project = projects(:albion_project)
    html = render_banner(project: project)

    assert_html(html, "img.banner-image")
    assert_no_html(html, ".banner-background")
  end

  def test_renders_without_banner_overlay_when_project_has_no_image
    project = projects(:empty_project)
    html = render_banner(project: project)

    # No banner image or overlay styling
    assert_no_html(html, "img.banner-image")
    assert_no_html(html, ".bottom-left")
    assert_no_html(html, ".banner-image-text")
  end

  def test_does_not_render_project_location_when_project_has_no_location
    project = projects(:empty_project)
    html = render_banner(project: project)

    assert_no_html(html, ".project_location")
  end

  def test_renders_project_location_when_project_has_location
    project = projects(:albion_project)
    html = render_banner(project: project)

    assert_html(html, ".project_location.banner-image-text")
    assert_html(html, "a[href='/locations/#{project.location.id}']")
    assert_includes(html, project.place_name)
  end

  def test_does_not_render_project_date_range_when_project_has_no_dates
    project = projects(:empty_project)
    html = render_banner(project: project)

    assert_no_html(html, ".project_date_range")
  end

  def test_renders_project_date_range_when_project_has_dates
    project = projects(:past_project)
    html = render_banner(project: project)

    # past_project has no image, so no banner-image-text class
    assert_html(html, ".project_date_range")
    assert_no_html(html, ".banner-image-text")
    assert_includes(html, project.date_range)
  end

  def test_renders_both_location_and_date_range_when_both_present
    project = projects(:past_project)
    html = render_banner(project: project)

    # past_project has no image, so no banner-image-text class
    assert_html(html, ".project_location")
    assert_html(html, ".project_date_range")
    assert_no_html(html, ".banner-image-text")
    assert_includes(html, project.place_name)
    assert_includes(html, project.date_range)
  end

  def test_renders_project_tabs_when_project_has_observations
    project = projects(:eol_project)
    html = render_banner(project: project)

    assert_html(html, "#project_tabs")
    assert_html(html, "ul.nav.nav-tabs")
    assert_html(html, "a.nav-link[href='/projects/#{project.id}']")
  end

  def test_renders_names_and_locations_tabs_for_empty_project
    project = projects(:empty_project)
    html = render_banner(project: project)

    assert_html(html, "#project_tabs")
    assert_includes(html, :NAMES.l)
    assert_includes(html, :LOCATIONS.l)
    # No targets, so no Update tab
    assert_not_includes(html, :project_updates_title.l)
  end

  def test_renders_update_tab_for_admin_with_targets
    project = projects(:rare_fungi_project)
    user = users(:rolf) # admin of rare_fungi_project
    html = render_banner(project: project, user: user)

    assert_html(html, "#project_tabs")
    assert_includes(html, :project_updates_title.l)
    assert_html(
      html,
      "a[href='/projects/#{project.id}/updates']"
    )
  end

  def test_does_not_render_update_tab_for_non_admin
    project = projects(:rare_fungi_project)
    user = users(:mary) # not admin
    html = render_banner(project: project, user: user)

    assert_not_includes(html, :project_updates_title.l)
  end

  def test_renders_admin_tab_for_admin
    project = projects(:rare_fungi_project)
    user = users(:rolf) # admin of rare_fungi_project
    html = render_banner(project: project, user: user)

    assert_html(html, "a[href='/projects/#{project.id}/admin']")
    assert_includes(html, :show_project_admin_tab.l)
  end

  def test_does_not_render_admin_tab_for_non_admin
    project = projects(:rare_fungi_project)
    user = users(:mary) # not admin of rare_fungi_project
    html = render_banner(project: project, user: user)

    assert_no_html(html, "a[href='/projects/#{project.id}/admin']")
  end

  def test_active_tab_highlights_current_tab
    project = projects(:eol_project)
    html = render_banner(project: project, current_tab: "observations")

    # Observations tab should have active class
    assert_match(/observations.*active/i, html)
  end

  def test_summary_tab_active_for_projects_controller
    project = projects(:eol_project)
    html = render_banner(project: project, current_tab: "projects")

    # Projects tab (summary) should have active class
    assert_html(html, "a.nav-link.active[href='/projects/#{project.id}']")
  end

  private

  def render_banner(project: projects(:eol_project),
                    user: nil, current_tab: nil)
    render(Components::ProjectBanner.new(project: project,
                                         user: user,
                                         current_tab: current_tab))
  end
end

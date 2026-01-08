# frozen_string_literal: true

require "test_helper"

# Tests for ProjectBanner component structure and conditional rendering.
# This component now handles all project banner logic internally including
# banner image, title, location, date range, and tabs.
class ProjectBannerTest < ComponentTestCase
  def test_renders_basic_html_structure
    html = render_banner

    # Outer row and container
    assert_html(html, ".row")
    assert_html(html, ".col-xs-12#project_banner")

    # Banner overlay positioning
    assert_html(html, ".bottom-left.ml-3.mb-3.p-2")

    # Title heading structure
    assert_html(html, "h1.h3.banner-image-text")
  end

  def test_title_id_is_title_when_on_project_page
    html = render_banner(on_project_page: true)

    assert_html(html, "h1#title")
    assert_no_html(html, "h1#banner_title")
  end

  def test_title_id_is_banner_title_when_not_on_project_page
    html = render_banner(on_project_page: false)

    assert_html(html, "h1#banner_title")
    assert_no_html(html, "h1#title")
  end

  def test_renders_banner_image_when_project_has_image
    project = projects(:albion_project)
    html = render_banner(project: project)

    assert_html(html, "img.banner-image")
    assert_no_html(html, ".banner-background")
  end

  def test_renders_banner_background_when_project_has_no_image
    project = projects(:empty_project)
    html = render_banner(project: project)

    assert_html(html, ".banner-background")
    assert_no_html(html, "img.banner-image")
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

    assert_html(html, ".project_date_range.banner-image-text")
    assert_includes(html, project.date_range)
  end

  def test_renders_both_location_and_date_range_when_both_present
    project = projects(:past_project)
    html = render_banner(project: project)

    assert_html(html, ".project_location.banner-image-text")
    assert_html(html, ".project_date_range.banner-image-text")
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

  def test_does_not_render_tabs_when_project_has_no_content
    project = projects(:empty_project)
    html = render_banner(project: project)

    assert_no_html(html, "#project_tabs")
  end

  private

  def render_banner(on_project_page: false, project: projects(:eol_project))
    render(Components::ProjectBanner.new(on_project_page: on_project_page,
                                         project: project))
  end
end

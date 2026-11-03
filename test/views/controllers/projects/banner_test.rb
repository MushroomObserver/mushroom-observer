# frozen_string_literal: true

require("test_helper")

module Views::Controllers::Projects
  # Tests for ProjectBanner component structure and conditional rendering.
  # This component now handles all project banner logic internally including
  # banner image, title, location, date range, and tabs.
  class BannerTest < ComponentTestCase
    def test_renders_basic_html_structure_with_banner_image
      project = projects(:albion_project)
      html = render_banner(project: project)

      # Outer row and container
      assert_html(html, ".row")
      assert_html(html, ".col-xs-12#project_banner")

      # Banner overlay positioning (only with images)
      assert_html(html, ".bottom-left")

      # Title heading structure with overlay styling
      assert_html(html, "#title.banner-image-text")
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
      assert_html(html, "#title.page-title")
    end

    def test_title_id_is_consistent_across_pages
      html = render_banner

      assert_html(html, "#title")
      assert_no_html(html, "#banner_title")
    end

    def test_title_includes_id_badge
      project = projects(:eol_project)
      html = render_banner(project: project)

      assert_html(html, "#title .badge-id")
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
      path = routes.location_path(project.location.id)
      assert_html(html, ".project_location a[href='#{path}']",
                  text: project.place_name)
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
      assert_html(html, ".project_date_range",
                  text: expected_date_range(project))
      assert_no_html(html, ".banner-image-text")
    end

    def test_renders_both_location_and_date_range_when_both_present
      project = projects(:past_project)
      html = render_banner(project: project)

      # past_project has no image, so no banner-image-text class
      assert_html(html, ".project_location", text: project.place_name)
      assert_html(html, ".project_date_range",
                  text: expected_date_range(project))
      assert_no_html(html, ".banner-image-text")
    end

    def test_renders_project_tabs_when_project_has_observations
      project = projects(:eol_project)
      html = render_banner(project: project)

      assert_html(html, "#project_tabs ul.nav-tabs")
      assert_html(html, "a.nav-link[href='#{routes.project_path(project.id)}']")
    end

    def test_renders_names_and_locations_tabs_for_empty_project
      project = projects(:empty_project)
      html = render_banner(project: project)

      assert_html(html, "#project_tabs a", text: :names.ti.as_displayed)
      assert_html(html, "#project_tabs a", text: :locations.ti.as_displayed)
      # No targets, so no Update tab
      assert_no_html(html, "#project_tabs a",
                     text: :project_updates_title.l.as_displayed)
    end

    def test_renders_update_tab_for_admin_with_targets
      project = projects(:rare_fungi_project)
      user = users(:rolf) # admin of rare_fungi_project
      html = render_banner(project: project, user: user)

      path = routes.project_updates_path(project_id: project.id)
      assert_html(html, "#project_tabs a[href='#{path}']",
                  text: :project_updates_title.l.as_displayed)
    end

    def test_does_not_render_update_tab_for_non_admin
      project = projects(:rare_fungi_project)
      user = users(:mary) # not admin
      html = render_banner(project: project, user: user)

      assert_no_html(html, "#project_tabs a",
                     text: :project_updates_title.l.as_displayed)
    end

    def test_renders_admin_tab_for_admin
      project = projects(:rare_fungi_project)
      user = users(:rolf) # admin of rare_fungi_project
      html = render_banner(project: project, user: user)

      path = routes.project_admin_path(project_id: project.id)
      assert_html(html, "#project_tabs a[href='#{path}']",
                  text: :show_project_admin_tab.l.as_displayed)
    end

    def test_does_not_render_admin_tab_for_non_admin
      project = projects(:rare_fungi_project)
      user = users(:mary) # not admin of rare_fungi_project
      html = render_banner(project: project, user: user)

      path = routes.project_admin_path(project_id: project.id)
      assert_no_html(html, "a[href='#{path}']")
    end

    def test_active_tab_highlights_current_tab
      project = projects(:eol_project)
      html = render_banner(project: project, current_tab: "observations")

      # Observations tab should have active class
      assert_html(html, "a.nav-link.active[href*='observations']")
    end

    def test_summary_tab_active_for_projects_controller
      project = projects(:eol_project)
      html = render_banner(project: project, current_tab: "projects")

      # Projects tab (summary) should have active class
      path = routes.project_path(project.id)
      assert_html(html, "a.nav-link.active[href='#{path}']")
    end

    def test_logged_out_banner_has_no_links_but_a_login_prompt
      project = projects(:albion_project)
      html = render_banner(project: project, user: nil)

      assert_html(html, "#title", text: project.title)
      assert_no_html(html, "#title a")
      assert_html(html, ".project_location", text: project.place_name)
      assert_no_html(html, ".project_location a")
      assert_html(html, "img.banner-image")
      assert_no_html(html, "#project_tabs ul.nav-tabs")
      assert_html(html, "#project_login_prompt",
                  text: :project_banner_login_prompt.l.as_displayed)
      assert_html(
        html,
        "#project_login_prompt a[href='#{routes.new_account_login_path}']"
      )
      assert_html(html, "a", count: 1)
    end

    private

    def render_banner(project: projects(:eol_project),
                      user: users(:mary), current_tab: nil)
      render(Banner.new(project: project,
                        user: user,
                        current_tab: current_tab))
    end

    def expected_date_range(project)
      "#{project.start_date.strftime("%Y-%m-%d")} to " \
        "#{project.end_date.strftime("%Y-%m-%d")}"
    end
  end
end

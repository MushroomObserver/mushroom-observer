# frozen_string_literal: true

require("test_helper")

module Views::Controllers::Projects
  # Tests for Banner's image/title/location/date-range rendering.
  # Tab rendering (#project_tabs, AdminSubtabs) lives on ProjectNavs --
  # see project_navs_test.rb.
  class BannerTest < ComponentTestCase
    # `#title` only belongs to this banner's title on `projects#show`
    # -- see `Banner#title_id`.
    def setup
      super
      controller.define_singleton_method(:controller_path) { "projects" }
      controller.define_singleton_method(:action_name) { "show" }
    end

    def test_renders_basic_html_structure_with_banner_image
      project = projects(:albion_project)
      html = render_banner(project: project)

      # Outer row and container
      assert_html(html, ".row")
      assert_html(html, ".col-12#project_banner")

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
      assert_html(html, ".col-12#project_banner")

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

    # Off projects#show, Header::PageTitle renders a distinct
    # heading, so this title must not also claim the #title id.
    def test_title_id_off_projects_show
      controller.define_singleton_method(:controller_path) do
        "projects/aliases"
      end
      controller.define_singleton_method(:action_name) { "new" }

      html = render_banner

      assert_no_html(html, "#title")
      assert_html(html, "#project_banner_title")
    end

    # Header::PageTitle is suppressed on every index action, so this
    # banner title is the page's only heading there, same as show.
    def test_title_id_on_project_index_page
      controller.define_singleton_method(:controller_path) do
        "projects/violations"
      end
      controller.define_singleton_method(:action_name) { "index" }

      html = render_banner

      assert_html(html, "#title")
      assert_no_html(html, "#project_banner_title")
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

    def test_logged_out_banner_has_no_links_but_a_login_prompt
      project = projects(:albion_project)
      project.title = "\"Albion\":https://example.com survey"
      html = render_banner(project: project, user: nil)

      assert_html(html, "#title", text: "Albion survey")
      assert_no_html(html, "#title a")
      assert_html(html, ".project_location", text: project.place_name)
      assert_no_html(html, ".project_location a")
      assert_html(html, "img.banner-image")
      assert_html(html, "#project_login_prompt",
                  text: :project_banner_login_prompt.l.as_displayed)
      assert_no_html(html, "a")
      ids = Nokogiri::HTML5.fragment(html).css("[id]").pluck("id")
      assert_operator(ids.index("project_login_prompt"), :<,
                      ids.index("project_banner"),
                      "Login prompt should come before the banner")
    end

    private

    def render_banner(project: projects(:eol_project), user: users(:mary))
      controller.instance_variable_set(:@user, user)
      render(Banner.new(project: project))
    end

    def expected_date_range(project)
      "#{project.start_date.strftime("%Y-%m-%d")} to " \
        "#{project.end_date.strftime("%Y-%m-%d")}"
    end
  end
end

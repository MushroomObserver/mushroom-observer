# frozen_string_literal: true

require "test_helper"

# Tests for ProjectBanner component structure and conditional rendering.
# Note: This component uses content_for blocks which are set by helpers
# (see ProjectsHelper#add_project_banner). Content integration is tested
# in controller/system tests, not component tests.
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
    assert_html(html, ".d-flex.align-items-center")
  end

  def test_title_id_is_title_when_is_project_true
    html = render_banner(is_project: true)

    assert_html(html, "h1#title")
    assert_no_html(html, "h1#banner_title")
  end

  def test_title_id_is_banner_title_when_is_project_false
    html = render_banner(is_project: false)

    assert_html(html, "h1#banner_title")
    assert_no_html(html, "h1#title")
  end

  def test_does_not_render_project_location_when_content_not_set
    html = render_banner

    assert_no_html(html, ".project_location")
  end

  def test_renders_project_location_when_content_set
    project = projects(:albion_project)
    html = render_banner_with_content(
      project: project,
      with_location: true
    )

    assert_html(html, ".project_location.banner-image-text")
    assert_includes(html, project.location.display_name)
  end

  def test_does_not_render_project_date_range_when_content_not_set
    html = render_banner

    assert_no_html(html, ".project_date_range")
  end

  def test_renders_project_date_range_when_content_set
    project = projects(:past_project)
    html = render_banner_with_content(
      project: project,
      with_date_range: true
    )

    assert_html(html, ".project_date_range.banner-image-text")
    assert_includes(html, project.date_range)
  end

  def test_renders_both_location_and_date_range_when_both_set
    project = projects(:past_project)
    html = render_banner_with_content(
      project: project,
      with_location: true,
      with_date_range: true
    )

    assert_html(html, ".project_location.banner-image-text")
    assert_html(html, ".project_date_range.banner-image-text")
    assert_includes(html, project.location.display_name)
    assert_includes(html, project.date_range)
  end

  private

  def render_banner(is_project: false)
    render(Components::ProjectBanner.new(is_project: is_project))
  end

  # Helper to render banner with content_for blocks set
  # (simulates how helpers like add_project_banner set content_for)
  def render_banner_with_content(project:, with_location: false,
                                 with_date_range: false,
                                 is_project: false)
    wrapper = Class.new(Phlex::HTML) do
      include Phlex::Rails::Helpers::ContentFor

      # rubocop:disable Lint/MissingSuper
      def initialize(project, banner, with_location, with_date_range)
        @project = project
        @banner = banner
        @with_location = with_location
        @with_date_range = with_date_range
      end
      # rubocop:enable Lint/MissingSuper

      def view_template
        if @with_location
          content_for(:project_location) do
            b { @project.location.display_name }
          end
        end
        if @with_date_range
          content_for(:project_date_range) do
            b { @project.date_range }
          end
        end
        render(@banner)
      end
    end

    banner_component = Components::ProjectBanner.new(is_project: is_project)
    render(wrapper.new(project, banner_component, with_location,
                       with_date_range))
  end
end

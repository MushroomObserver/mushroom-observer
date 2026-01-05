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

  private

  def render_banner(is_project: false)
    render(Components::ProjectBanner.new(is_project: is_project))
  end
end

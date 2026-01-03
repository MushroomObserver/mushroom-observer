# frozen_string_literal: true

require "test_helper"

module Sidebar
  class LatestTest < ComponentTestCase
    def test_renders_heading_and_links
      html = render_component

      # Should have heading with "Latest:" text
      assert_includes(html, :app_latest.t)

      # Should include navigation links
      assert_includes(html, "nav_articles_link")
      assert_includes(html, "nav_activity_logs_link")
      assert_includes(html, "nav_images_link")
      assert_includes(html, "nav_comments_link")

      # Should have indent class on links
      assert_includes(html, "list-group-item indent")

      # Should have nav-active data attributes for active link tracking
      assert_includes(html, "data-nav-active-target=\"link\"")
    end

    def test_heading_has_correct_css_classes
      html = render_component

      # Heading should have the disabled and font-weight-bold classes
      assert_html(
        html,
        "div.list-group-item.disabled.font-weight-bold"
      )
    end

    def test_renders_only_news_link_for_guest_users
      html = render_component(user: nil)

      # Should have heading
      assert_includes(html, :app_latest.t)

      # Should have news link (available to all)
      assert_includes(html, "nav_articles_link")

      # Should NOT have user-only links
      assert_not_includes(html, "nav_activity_logs_link")
      assert_not_includes(html, "nav_images_link")
      assert_not_includes(html, "nav_comments_link")
    end

    private

    def render_component(user: users(:rolf))
      classes = {
        heading: "list-group-item disabled font-weight-bold",
        indent: "list-group-item indent"
      }
      render(Components::Sidebar::Latest.new(user: user, classes: classes))
    end
  end
end

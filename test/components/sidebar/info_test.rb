# frozen_string_literal: true

require "test_helper"

module Sidebar
  class InfoTest < ComponentTestCase
    def test_renders_heading_and_links
      html = render_component

      # Should have heading with "More:" text
      assert_includes(html, :app_more.t)

      # Should include navigation links
      assert_includes(html, "nav_mobile_app_link")
      assert_includes(html, "nav_intro_link")
      assert_includes(html, "nav_how_to_use_link")
      assert_includes(html, "nav_donate_link")
      assert_includes(html, "nav_how_to_help_link")
      assert_includes(html, "nav_bug_report_link")
      assert_includes(html, "nav_ask_webmaster_link")
      assert_includes(html, "nav_contributors_link")
      assert_includes(html, "nav_site_stats_link")
      assert_includes(html, "nav_translators_note_link")
      assert_includes(html, "nav_publications_link")
      assert_includes(html, "nav_privacy_policy_link")

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

    private

    def render_component
      classes = {
        heading: "list-group-item disabled font-weight-bold",
        indent: "list-group-item indent"
      }
      render(Components::Sidebar::Info.new(classes: classes))
    end
  end
end

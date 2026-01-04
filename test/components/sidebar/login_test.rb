# frozen_string_literal: true

require "test_helper"

module Sidebar
  class LoginTest < ComponentTestCase
    def test_renders_heading_with_icon_and_links
      html = render_component

      # Should have heading with icon and "Account:" text
      assert_includes(html, :app_account.t)
      assert_includes(html, "glyphicon glyphicon-user")

      # Should include navigation links
      assert_includes(html, "nav_login_link")
      assert_includes(html, "nav_signup_link")

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

    def test_heading_contains_icon_and_span
      html = render_component

      # Should have icon before text
      assert_html(html, "div.list-group-item i.glyphicon.glyphicon-user")
      assert_html(html, "div.list-group-item span")
    end

    private

    def render_component
      classes = {
        heading: "list-group-item disabled font-weight-bold",
        indent: "list-group-item indent"
      }
      render(Components::Sidebar::Login.new(classes: classes))
    end
  end
end

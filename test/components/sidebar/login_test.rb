# frozen_string_literal: true

require "test_helper"

module Sidebar
  class LoginTest < ComponentTestCase
    include Tabs::Sidebar::LoginHelper
    include Rails.application.routes.url_helpers

    def setup
      super
      @original_default_url_options =
        Rails.application.routes.default_url_options.dup
      Rails.application.routes.default_url_options[:host] = "test.host"
    end

    def teardown
      Rails.application.routes.default_url_options.replace(
        @original_default_url_options
      )
      super
    end

    def test_renders_heading_with_icon_and_links
      html = render_component

      # Should have heading with icon and "Account:" text
      assert_includes(html, :app_account.t)
      assert_html(html, "i.glyphicon.glyphicon-user")

      # Should include navigation links
      assert_html(html, "a#nav_login_link")
      assert_html(html, "a#nav_signup_link")

      # Should have indent class on links
      assert_html(html, "a.list-group-item.indent")

      # Should have nav-active data attributes for active link tracking
      assert_html(html, "a[data-nav-active-target='link']")
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
      render(Components::Sidebar::Login.new(
               heading_key: :app_account,
               tabs: sidebar_login_tabs,
               classes: classes
             ))
    end
  end
end

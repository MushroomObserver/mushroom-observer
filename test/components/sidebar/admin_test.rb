# frozen_string_literal: true

require "test_helper"

module Sidebar
  class AdminTest < ComponentTestCase
    include Tabs::Sidebar::AdminHelper
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

    def test_renders_heading_links_and_button
      html = render_component

      # Should have heading with "Admin:" text
      assert_includes(html, :app_admin.t)

      # Should include navigation links
      assert_html(html, "a#nav_admin_jobs_link")
      assert_html(html, "a#nav_admin_blocked_ips_link")
      assert_html(html, "a#nav_admin_switch_users_link")
      assert_html(html, "a#nav_admin_user_index_link")
      assert_html(html, "a#nav_admin_edit_banner_link")
      assert_html(html, "a#nav_admin_licenses_link")

      # Should have admin class on links (not indent)
      assert_html(html, "a.list-group-item.admin")

      # Should have nav-active data attributes for active link tracking
      assert_html(html, "a[data-nav-active-target='link']")

      # Should have "Turn Admin Off" button
      assert_includes(html, :app_turn_admin_off.t)
      assert_html(html, "button#nav_admin_off_link")
      assert_html(html, "button.btn.btn-link")
    end

    def test_heading_has_correct_css_classes
      html = render_component

      # Heading should have the disabled and font-weight-bold classes
      assert_html(
        html,
        "div.list-group-item.disabled.font-weight-bold"
      )
    end

    def test_turn_off_button_is_post_request
      html = render_component

      # Button should use POST method (no _method field needed for POST)
      assert_html(html, "form[method='post']")
    end

    private

    def render_component
      classes = {
        heading: "list-group-item disabled font-weight-bold",
        admin: "list-group-item admin"
      }
      render(Components::Sidebar::Admin.new(
               heading_key: :app_admin,
               tabs: sidebar_admin_tabs,
               classes: classes
             ))
    end
  end
end

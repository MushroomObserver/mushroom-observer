# frozen_string_literal: true

require "test_helper"

class Views::Layouts::Sidebar
  class AdminTest < ComponentTestCase
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
      assert_html(html, ".jobs_link")
      assert_html(html, ".blocked_ips_link")
      assert_html(html, ".switch_users_link")
      assert_html(html, ".list_users_link")
      assert_html(html, ".change_site_banner_link")
      assert_html(html, ".licenses_link")

      # Should have admin class on links (not indent)
      assert_html(html, ".list-group-item.admin")

      # Should have nav-active data attributes for active link tracking
      assert_html(html, "a[data-nav-active-target='link']")

      # Should have "Turn Admin Off" button
      assert_includes(html, :app_turn_admin_off.t)
      assert_html(html, ".admin_mode_link")
      assert_html(html, ".btn.btn-link")
    end

    def test_heading_has_correct_css_classes
      html = render_component

      # Heading should have the disabled and font-weight-bold classes
      assert_html(html, ".list-group-item.disabled.font-weight-bold")
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
      render(Admin.new(
               heading_key: :app_admin,
               tabs: Tab::Sidebar::AdminActions.new.map(&:to_a),
               classes: classes
             ))
    end
  end
end

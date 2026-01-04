# frozen_string_literal: true

require "test_helper"

module Sidebar
  class UserTest < ComponentTestCase
    def setup
      super
      @user = users(:rolf)
    end

    def test_renders_heading_with_username_and_icon
      html = render_component

      # Should have heading with icon and username
      assert_html(html, "div.list-group-item i.glyphicon.glyphicon-user")
      assert_includes(html, @user.login)
      assert_html(html, "span.ml-2")

      # Should have mobile_only class
      assert_includes(html, "mobile-only")
    end

    def test_renders_logout_button
      html = render_component

      # Should have logout button
      assert_includes(html, :app_logout.t)
      assert_includes(html, "nav_user_logout_link")
      assert_includes(html, "btn btn-link")
    end

    def test_renders_user_tabs
      html = render_component

      # Should have navigation links
      assert_includes(html, "nav_join_mailing_list_link")

      # Should have mobile_only class on links
      assert_includes(html, "mobile-only")
    end

    def test_shows_admin_button_for_admin_not_in_admin_mode
      @user.admin = true
      html = render_component(in_admin_mode: false)

      # Should have "Turn Admin On" button
      assert_includes(html, :app_turn_admin_on.t)
      assert_includes(html, "nav_mobile_admin_link")
    end

    def test_hides_admin_button_for_non_admin
      @user.admin = false
      html = render_component(in_admin_mode: false)

      # Should NOT have "Turn Admin On" button
      assert_not_includes(html, :app_turn_admin_on.t)
      assert_not_includes(html, "nav_mobile_admin_link")
    end

    def test_hides_admin_button_when_in_admin_mode
      @user.admin = true
      html = render_component(in_admin_mode: true)

      # Should NOT have "Turn Admin On" button (already in admin mode)
      assert_not_includes(html, :app_turn_admin_on.t)
      assert_not_includes(html, "nav_mobile_admin_link")
    end

    private

    def render_component(in_admin_mode: false)
      classes = {
        heading: "list-group-item disabled font-weight-bold",
        indent: "list-group-item indent",
        mobile_only: "mobile-only"
      }
      render(
        Components::Sidebar::User.new(
          user: @user,
          classes: classes,
          in_admin_mode: in_admin_mode
        )
      )
    end
  end
end

# frozen_string_literal: true

require("test_helper")

module Views::Layouts::App
  class BannersTest < ComponentTestCase
    def test_no_admin_or_site_banner_renders_empty
      html = render_banners

      assert_html(html, "#banners")
      assert_no_html(html, "#admin_banner")
      assert_no_html(html, ".alert")
    end

    def test_admin_mode_renders_danger_banner
      stub_admin_mode!
      html = render_banners

      assert_html(html, "#admin_banner",
                  text: "DANGER: You are in administrator mode. " \
                        "Proceed with caution.")
    end

    def test_impersonation_renders_danger_banner
      controller.instance_variable_set(:@user, users(:rolf))
      html = render_banners(real_user_id: users(:rolf).id)

      assert_html(html, "#admin_banner",
                  text: "DANGER: You are currently logged in as " \
                        "#{users(:rolf).login}.")
    end

    def test_site_banner_renders_message_and_dismiss_button
      banner = banners(:one)
      html = render_banners(banner: banner)

      assert_html(html, "div.alert.message-banner[data-banner-target='banner']")
      assert_html(html, ".alert p", text: banner.message.t.as_displayed)
      assert_html(html,
                  "#dismiss-banner[data-banner-target='dismissButton']" \
                  "[data-version='#{banner.version}']" \
                  "[aria-label='#{:close.ti}']")
      assert_html(html, "#dismiss-banner svg.mo-icon-chevron-up")
    end

    private

    def render_banners(banner: nil, real_user_id: nil)
      session = { real_user_id: real_user_id }
      controller.define_singleton_method(:session) { session }
      render(Banners.new(banner: banner))
    end
  end
end

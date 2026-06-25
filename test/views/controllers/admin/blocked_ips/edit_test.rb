# frozen_string_literal: true

require("test_helper")

module Views::Controllers::Admin::BlockedIps
  class EditTest < ComponentTestCase
    def test_refresh_link_navigates_to_edit_path
      html = render_edit

      assert_html(html,
                  "a[href='#{routes.edit_admin_blocked_ips_path}']",
                  text: "Refresh Stats")
    end

    private

    def ip_list(ips: [])
      ::Admin::BlockedIps::IpListState[
        ips: ips, page: 1, total_pages: 1,
        total_count: ips.size, starts_with: nil
      ]
    end

    def render_edit
      render(Edit.new(
               stats: {},
               okay: ip_list,
               blocked: ip_list
             ))
    end
  end
end

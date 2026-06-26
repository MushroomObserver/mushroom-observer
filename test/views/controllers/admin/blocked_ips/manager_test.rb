# frozen_string_literal: true

require("test_helper")

module Views::Controllers::Admin::BlockedIps
  class ManagerTest < ComponentTestCase
    def setup
      super
      IpStats.reset!
    end

    def test_renders_blocked_ips_structure
      html = render_manager(type: :blocked, ips: ["1.2.3.4", "5.6.7.8"])

      # Turbo frame wrapper
      assert_html(html, "turbo-frame#blocked_ips_list")

      # Panel structure with collapsible
      assert_html(html, ".panel.panel-default")
      assert_html(html, ".panel-collapse-trigger")
      assert_html(html, "#blocked_ips_body")

      # Form structure
      assert_html(html, "#blocked_ips_manager_form")
      assert_html(html, "form[action='/admin/blocked_ips']")
      assert_html(html, "input[name='_method'][value='patch']")

      # Add field and buttons
      assert_html(html, "input[name='blocked_ips[add_bad]']")
      assert_html(html, "#clear_blocked_ips_list")

      # Table with IPs — each row contains a td and a remove button
      # carrying name="remove_bad" + the IP as its value (and matching id).
      assert_html(html, "#blocked_ips tbody td", text: "1.2.3.4")
      assert_html(html,
                  "button[name='remove_bad'][value='1.2.3.4']" \
                  "[id='remove_blocked_ip_1.2.3.4']")
      assert_html(html, "button[name='remove_bad'][value='5.6.7.8']")
    end

    def test_renders_okay_ips_structure
      html = render_manager(type: :okay, ips: ["10.0.0.1"])

      assert_html(html, "turbo-frame#okay_ips_list")
      assert_html(html, "#okay_ips_manager_form")
      assert_html(html, "input[name='okay_ips[add_okay]']")
      assert_html(html, "#clear_okay_ips_list")
      assert_html(html, "#okay_ips tbody td", text: "10.0.0.1")
      assert_html(html,
                  "button[name='remove_okay'][value='10.0.0.1']" \
                  "[id='remove_okay_ip_10.0.0.1']")
    end

    def test_renders_with_pagination
      html = render_manager(
        type: :blocked,
        ips: ["1.2.3.4"],
        page: 2,
        total_pages: 5,
        total_count: 100
      )

      # Shows pagination info in the panel heading, e.g.
      # "Showing 1 of 100 (page 2 of 5)".
      assert_html(html, ".panel-heading-links", text: "Showing 1 of 100")
      assert_html(html, ".panel-heading-links", text: "page 2 of 5")

      # Renders filter form
      assert_html(html, "#blocked-ips-list-filter-form")
    end

    # Defensive `filterable?` check in `Manager`: when an IpListState
    # is constructed with nil pagination fields (currently never the
    # case in production, but the view tolerates it), no filter form
    # or "of TOTAL" / "page X of Y" pagination message renders.
    def test_renders_without_pagination
      html = render_manager(type: :okay, ips: ["1.2.3.4"],
                            page: nil, total_pages: nil, total_count: nil)

      heading = Nokogiri::HTML(html).at_css(".panel-heading-links")
      assert(heading, "Expected .panel-heading-links element")
      assert_includes(heading.text, "Showing 1")
      assert_not_includes(heading.text, "page")
      assert_no_html(html, "#okay-ips-list-filter-form")
    end

    def test_renders_empty_list
      html = render_manager(type: :blocked, ips: [])

      assert_html(html, "#blocked_ips")
      assert_html(html, "tbody")
    end

    def test_panel_is_collapsible_and_expanded
      html = render_manager(type: :blocked, ips: ["1.2.3.4"])

      # Has collapse trigger — all on the same <a>
      assert_html(
        html,
        "a.panel-collapse-trigger[data-toggle='collapse']" \
        "[href='#blocked_ips_body']"
      )

      # Body is expanded by default (has "in" class)
      assert_html(html, ".panel-collapse.collapse.in")
    end

    private

    # Defaults page/total_pages/total_count to the values production
    # always supplies (page 1, single page covering all `ips`) so the
    # default render path mirrors the controller. Tests that exercise
    # the nil/defensive path pass them explicitly.
    def render_manager(type:, ips:, **opts)
      form = if type == :blocked
               FormObject::BlockedIps.new
             else
               FormObject::OkayIps.new
             end
      list = ::Admin::BlockedIps::IpListState[
        ips: ips,
        page: opts.fetch(:page, 1),
        total_pages: opts.fetch(:total_pages, 1),
        total_count: opts.fetch(:total_count, ips.size),
        starts_with: opts[:starts_with]
      ]
      render(Manager.new(form, type: type, list: list))
    end
  end
end

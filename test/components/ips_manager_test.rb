# frozen_string_literal: true

require("test_helper")

class IpsManagerTest < ComponentTestCase
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

    # Table with IPs
    assert_html(html, "#blocked_ips")
    assert_includes(html, "1.2.3.4")
    assert_includes(html, "5.6.7.8")
    assert_includes(html, 'id="remove_blocked_ip_1.2.3.4"')
  end

  def test_renders_okay_ips_structure
    html = render_manager(type: :okay, ips: ["10.0.0.1"])

    assert_html(html, "turbo-frame#okay_ips_list")
    assert_html(html, "#okay_ips_manager_form")
    assert_html(html, "input[name='okay_ips[add_okay]']")
    assert_html(html, "#clear_okay_ips_list")
    assert_html(html, "#okay_ips")
    assert_includes(html, "10.0.0.1")
    assert_includes(html, 'id="remove_okay_ip_10.0.0.1"')
  end

  def test_renders_with_pagination
    html = render_manager(
      type: :blocked,
      ips: ["1.2.3.4"],
      page: 2,
      total_pages: 5,
      total_count: 100,
      filter_path: "/admin/blocked_ips/edit"
    )

    # Shows pagination info
    assert_includes(html, "Showing 1 of 100")
    assert_includes(html, "page 2 of 5")

    # Renders filter form
    assert_html(html, "#blocked-ips-list-filter-form")
  end

  def test_renders_without_pagination
    html = render_manager(type: :okay, ips: ["1.2.3.4"])

    assert_includes(html, "Showing 1")
    assert_not_includes(html, "page")
    assert_no_html(html, "#okay-ips-list-filter-form")
  end

  def test_renders_empty_list
    html = render_manager(type: :blocked, ips: [])

    assert_html(html, "#blocked_ips")
    assert_html(html, "tbody")
  end

  def test_panel_is_collapsible_and_expanded
    html = render_manager(type: :blocked, ips: ["1.2.3.4"])

    # Has collapse trigger
    assert_html(html, ".panel-collapse-trigger")
    assert_html(html, "[data-toggle='collapse']")
    assert_html(html, "[data-target='#blocked_ips_body']")

    # Body is expanded by default (has "in" class)
    assert_html(html, ".panel-collapse.collapse.in")
  end

  private

  def render_manager(type:, ips:, **opts)
    form = if type == :blocked
             FormObject::BlockedIps.new
           else
             FormObject::OkayIps.new
           end
    render(Components::IpsManager.new(
             form,
             type: type,
             ips: ips,
             action_path: "/admin/blocked_ips",
             page: opts[:page],
             total_pages: opts[:total_pages],
             total_count: opts[:total_count],
             starts_with: opts[:starts_with],
             filter_path: opts[:filter_path]
           ))
  end
end

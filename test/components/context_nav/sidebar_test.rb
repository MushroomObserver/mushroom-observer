# frozen_string_literal: true

require("test_helper")

module Components::ContextNav
  # Tests for the mobile (`xs`-only) sidebar that renders into
  # `content_for(:context_nav_mobile)`. Sidebar collapses every link
  # tuple to an `active_link_to` — ignoring `args[:button]` — so the
  # mobile menu stays a flat list, matching pre-Phlex behavior.
  class SidebarTest < ComponentTestCase
    def setup
      super
      @article = articles(:premier_article)
    end

    def test_renders_nothing_when_links_empty
      html = render(Components::ContextNav::Sidebar.new(links: []))

      assert_equal("", html)
    end

    def test_renders_heading_and_link_rows
      html = render_sidebar(simple_links)

      # Heading: "Context Actions:" inside a list-group-item / heading
      # div, mobile-only.
      assert_html(html, "div.list-group-item.disabled.font-weight-bold.visible-xs",
                  text: "#{:app_context_actions.t}:")
      # Each link becomes its own indented + mobile-only row.
      assert_html(html, "a.list-group-item.indent.visible-xs",
                  count: simple_links.length)
    end

    # Sidebar deliberately collapses `button: :destroy` to a plain
    # link (no form, no destroy mechanics) — this matches the
    # pre-Phlex `sidebar_nav_link` shape, and the mobile menu has
    # no good place for confirm dialogs anyway.
    def test_destroy_tuple_renders_as_plain_link_in_sidebar
      links = [[nil, @article, { button: :destroy }]]
      html = render_sidebar(links)

      assert_no_html(html, "form")
    end

    # Every sidebar link gets the Stimulus `nav-active` data attrs
    # so the controller can highlight the current-page link.
    def test_links_have_nav_active_data_attributes
      html = render_sidebar(simple_links)

      assert_html(html, "a[data-nav-active-target='link']")
      assert_html(html, "a[data-action='nav-active#navigate']")
    end

    def test_strips_d_block_class_from_buttons
      links = [["Click", "/items", { button: :post, class: "d-block other-class" }]]
      html = render_sidebar(links)

      # The link still renders (sidebar collapses buttons to links),
      # but the d-block was stripped out per pre-Phlex parity.
      assert_html(html, "a.other-class")
      assert_no_html(html, "a.d-block")
    end

    private

    def render_sidebar(links)
      render(Components::ContextNav::Sidebar.new(links: links))
    end

    def simple_links
      [
        ["Edit", "/items/1/edit", { class: "edit_link" }],
        ["Show", "/items/1", { class: "show_link" }]
      ]
    end
  end
end

# frozen_string_literal: true

require("test_helper")

module Components::ContextNav
  # Tests for the mobile (`xs`-only) sidebar that renders into
  # `content_for(:context_nav_mobile)`. Sidebar dispatches each link
  # tuple via `LinkRendering#render_crud_button_or_link` (same as
  # `TopBar`) so destroy / post / put / patch tuples render as their
  # actual forms — pre-Phlex `sidebar_nav_link` collapsed everything
  # to plain links, which was a bug (mobile users couldn't trigger
  # the action). Fixed in this PR.
  class SidebarTest < ComponentTestCase
    def setup
      super
      @article = articles(:premier_article)
    end

    def test_renders_nothing_when_links_empty
      html = render(Components::ContextNav::Sidebar.new(links: []))

      assert_equal("", html)
    end

    def test_renders_heading_and_plain_link_rows
      html = render_sidebar(simple_links)

      # Heading row.
      heading_classes =
        "div.list-group-item.disabled.font-weight-bold.visible-xs"
      assert_html(html, heading_classes,
                  text: "#{:app_context_actions.t}:")
      # Each plain link is its own indented + mobile-only row.
      assert_html(html, "a.list-group-item.indent.visible-xs",
                  count: simple_links.length)
    end

    # `button: :destroy` now dispatches through `CrudButton::Delete`
    # (with the `icon: nil` + `btn: nil` context-nav opt-outs from
    # `LinkRendering`) — sidebar users get a working REMOVE form.
    def test_destroy_tuple_renders_as_form_in_sidebar
      links = [[nil, @article, { button: :destroy }]]
      html = render_sidebar(links)

      assert_html(html, "form[action='#{routes.article_path(@article)}']")
      assert_html(html, "input[name='_method'][value='delete']")
    end

    # `button: :post` dispatches through Rails' `button_to` → form.
    def test_post_tuple_renders_as_form_in_sidebar
      links = [["Submit", "/items", { button: :post }]]
      html = render_sidebar(links)

      assert_html(html, "form[action='/items']")
      assert_html(html, "button", text: "Submit")
    end

    # Plain anchor links get the Stimulus `nav-active` data attrs so
    # the current-page link is highlighted. Forms / buttons aren't
    # navigated to in the same sense, so they don't get those attrs.
    def test_plain_links_have_nav_active_data_attributes
      html = render_sidebar(simple_links)

      assert_html(html, "a[data-nav-active-target='link']")
      assert_html(html, "a[data-action='nav-active#navigate']")
    end

    def test_button_tuples_do_not_get_nav_active_data_attributes
      links = [[nil, @article, { button: :destroy }]]
      html = render_sidebar(links)

      assert_no_html(html, "form[data-nav-active-target]")
      assert_no_html(html, "button[data-nav-active-target]")
    end

    def test_strips_d_block_class_from_buttons
      links = [["Click", "/items",
                { button: :post, class: "d-block other-class" }]]
      html = render_sidebar(links)

      assert_html(html, "button.other-class")
      assert_no_html(html, "button.d-block")
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

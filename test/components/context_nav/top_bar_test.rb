# frozen_string_literal: true

require("test_helper")

module Components::ContextNav
  # Tests for the right-side dropdown that renders into
  # `content_for(:context_nav)`. Covers the basic structure, the
  # per-link dispatch via `args[:button]`, and the `d-block`-stripping
  # quirk inherited from the pre-Phlex helper.
  class TopBarTest < ComponentTestCase
    def setup
      super
      @article = articles(:premier_article)
    end

    # No links → no markup at all (the entire dropdown is conditional
    # on having something to put inside it).
    def test_renders_nothing_when_links_empty
      html = render(Components::ContextNav::TopBar.new(links: []))

      assert_equal("", html)
    end

    # Compacts nil entries before the empty check — a tabs helper
    # that returns `[edit_tab, destroy_tab_if_admin]` shouldn't
    # collapse the dropdown when one entry is nil.
    def test_renders_nothing_when_all_links_are_nil
      html = render(Components::ContextNav::TopBar.new(links: [nil, nil]))

      assert_equal("", html)
    end

    def test_renders_bootstrap_dropdown_structure
      html = render_top_bar(simple_links)

      assert_html(html, "li.dropdown.d-inline-block")
      assert_html(html, "a.dropdown-toggle#context_nav_toggle")
      assert_html(html, "ul.dropdown-menu#context_nav")
      # Each link tuple becomes one <li> inside the dropdown menu
      assert_html(html, "ul.dropdown-menu li", count: simple_links.length)
    end

    # The dropdown's toggle shows the localized "Context Actions"
    # label inside a span with the `dropdown_current_target` hook
    # so the Stimulus controller can rewrite it on submenu changes.
    def test_dropdown_toggle_shows_context_actions_label
      html = render_top_bar(simple_links)

      title_sel =
        "a.dropdown-toggle span[data-dropdown-current-target='title']"
      assert_html(html, title_sel, text: :app_context_actions.l)
    end

    # `args[:button] => :destroy` routes through `CrudButton::Delete`
    # with the context-nav opt-outs (`icon: nil`, `btn: nil`) so the
    # destroy renders as plain `[ DESTROY ]`-style text.
    def test_destroy_button_renders_as_plain_text_link
      links = [[nil, @article, { button: :destroy }]]
      html = render_top_bar(links)

      assert_html(html, "form[action='#{view_context.article_path(@article)}']")
      assert_html(html, "input[name='_method'][value='delete']")
      assert_no_html(html, ".glyphicon-remove-circle")
      assert_no_html(html, ".btn.btn-outline-default")
    end

    # `args[:button] => :post` uses Rails' `button_to`.
    def test_post_button_renders_as_form
      links = [["Click", "/items", { button: :post }]]
      html = render_top_bar(links)

      assert_html(html, "form[action='/items']")
      assert_html(html, "button", text: "Click")
    end

    # Plain links (no `args[:button]`) render as `<a>`.
    def test_plain_link_renders_as_anchor
      links = [["Edit", "/items/1/edit", { class: "edit_item_link" }]]
      html = render_top_bar(links)

      assert_html(html, "a.edit_item_link[href='/items/1/edit']", text: "Edit")
    end

    # The dropdown menu strips `d-block` from button classes — the
    # pre-Phlex helper did this so button-style links don't get
    # forced to display: block inside the dropdown.
    def test_strips_d_block_class_from_buttons
      links = [["Submit", "/items", { button: :post, class: "d-block btn-lg" }]]
      html = render_top_bar(links)

      assert_html(html, "button.btn-lg")
      assert_no_html(html, "button.d-block")
    end

    private

    def render_top_bar(links)
      render(Components::ContextNav::TopBar.new(links: links))
    end

    def simple_links
      [
        ["Edit", "/items/1/edit", { class: "edit_link" }],
        ["Show", "/items/1", { class: "show_link" }]
      ]
    end
  end
end

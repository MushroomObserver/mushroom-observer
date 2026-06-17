# frozen_string_literal: true

require("test_helper")

module Views::Layouts
  class Header::SorterTest < ComponentTestCase
    def setup
      super
      controller.params[:controller] = "names"
      controller.params[:action] = "index"
      # The MO controllers expose `controller_model_name` (via
      # `ApplicationController::Indexes`) so the Sorter can derive
      # `<plural>_by_<key>_link` identifier classes. The
      # `ActionView::TestCase::TestController` doesn't have it; stub
      # to the model name the test queries against.
      controller.define_singleton_method(:controller_model_name) { "Name" }
      @sorts = [
        ["created_at", :sort_by_created_at.t],
        ["updated_at", :sort_by_updated_at.t]
      ]
    end

    def test_renders_nothing_when_no_query
      html = render(Header::Sorter.new(query: nil, sorts: @sorts))

      assert_equal("", html)
    end

    def test_renders_nothing_when_no_sorts
      html = render(Header::Sorter.new(query: query_with(num_results: 5),
                                       sorts: nil))

      assert_equal("", html)
    end

    def test_renders_nothing_when_only_one_result
      html = render(Header::Sorter.new(query: query_with(num_results: 1),
                                       sorts: @sorts))

      assert_equal("", html)
    end

    def test_renders_outer_ul_with_label_and_dropdown
      html = render(Header::Sorter.new(query: query_with(num_results: 5),
                                       sorts: @sorts))

      # Outer is a `<ul>`, not a `<div>` — semantically a list of nav
      # items (label + dropdown).
      assert_html(html, "ul.navbar-flex.sorter")
      # The label is the first `<li>`.
      assert_html(html, "ul.sorter > li.navbar-text",
                  text: "#{:sort_by_header.l}:")
      # The dropdown is the second `<li>`; Components::Dropdown
      # renders its outer wrapper as `<li class="dropdown d-inline-block">`
      # and the Sorter passes `wrapper_class: "navbar-form px-2"` for
      # navbar spacing.
      assert_html(html, "ul.sorter > li.dropdown.navbar-form")
      # Toggle `<a>` carries the btn styling the legacy sort-bar used.
      assert_html(html, "li.dropdown a.dropdown-toggle.btn.btn-outline-default")
      # Menu carries the `sorts` extra class.
      assert_html(html, "ul.dropdown-menu.sorts")
    end

    def test_menu_contains_mobile_only_sort_by_header
      html = render(Header::Sorter.new(query: query_with(num_results: 5),
                                       sorts: @sorts))

      # `menu_header:` slot — visible-xs `<li>` rendered above the
      # section's links.
      assert_html(html, "ul.dropdown-menu.sorts > li.visible-xs",
                  text: "#{:sort_by_header.l}:")
    end

    def test_active_sort_is_marked_active_and_disabled
      html = render(Header::Sorter.new(
                      query: query_with(num_results: 5,
                                        order_by: "created_at"),
                      sorts: @sorts
                    ))

      # `args[:active] = true` in the Sorter's tuples flows through
      # `Components::Dropdown#render_link`: the current sort gets
      # `.active` + `disabled`.
      assert_html(html, "a.names_by_created_at_link.active[disabled]")
      # The non-active sort is a plain link — present, not disabled.
      assert_html(html, "a.names_by_updated_at_link")
      assert_no_html(html, "a.names_by_updated_at_link[disabled]")
    end

    def test_reverse_link_is_appended
      html = render(Header::Sorter.new(
                      query: query_with(num_results: 5,
                                        order_by: "created_at"),
                      sorts: @sorts
                    ))

      # `Reverse` is always the last tuple in the menu, with the
      # `<plural>_by_reverse_<current>_link` id-style class.
      assert_html(html, "a.names_by_reverse_created_at_link",
                  text: :sort_by_reverse.t)
    end

    def test_link_all_skips_active_disabled_state
      html = render(Header::Sorter.new(
                      query: query_with(num_results: 5,
                                        order_by: "created_at"),
                      sorts: @sorts, link_all: true
                    ))

      # With `link_all: true`, no tuple is `.active`; every option
      # stays a live, undisabled link.
      assert_no_html(html, "a.active[disabled]")
      assert_html(html, "a.names_by_created_at_link")
      assert_no_html(html, "a.names_by_created_at_link[disabled]")
    end

    private

    # Real `Query` instance — Sorter's prop type rejects duck-typed
    # stubs. `num_results` is stubbed via `define_singleton_method`
    # so the test can drive the `visible?` gate without seeding a
    # specific fixture row count.
    def query_with(num_results:, order_by: "created_at")
      query = ::Query.lookup(:Name, order_by: order_by)
      query.save
      query.define_singleton_method(:num_results) { num_results }
      query
    end
  end
end

# frozen_string_literal: true

require("test_helper")

module Views::Layouts
  class Header::IndexPaginationNavTest < ComponentTestCase
    def setup
      super
      @request_url = "/observations?q%5Bmodel%5D=Observation"
    end

    def test_renders_basic_structure_with_position_top
      html = render_nav(position: :top, pagination_data: paginated(50, 1))

      # Main container has correct position class
      assert_includes(html, 'class="pagination-top flex-bar mb-2"')

      # Contains two d-flex divs
      assert_html(html, "div.pagination-top > div.d-flex", count: 2)
    end

    def test_renders_basic_structure_with_position_bottom
      html = render_nav(position: :bottom, pagination_data: paginated(50, 1))

      assert_includes(html, 'class="pagination-bottom flex-bar mb-2"')
    end

    def test_renders_number_pagination_when_multiple_pages
      html = render_nav(pagination_data: paginated(50, 1))

      assert_includes(html, 'class="paginate pagination_numbers flex-bar')
      assert_includes(html, "prev_page_link")
      assert_includes(html, "next_page_link")
      assert_includes(html, 'class="input-group page-input mx-2"')
      # Should have the max page link (5 pages = 50/10)
      assert_nested(
        html, parent_selector: "nav.pagination_numbers",
              child_selector: "a", text: "5"
      )
    end

    def test_does_not_render_number_pagination_when_single_page
      html = render_nav(pagination_data: paginated(5, 1))

      assert_not_includes(html, "pagination_numbers")
    end

    def test_page_links_are_styled_as_large_link_buttons
      html = render_nav(pagination_data: paginated(50, 1))

      # Rendered via Link::Get's button:/size: kwargs, not via raw
      # btn/btn-lg strings — see Components::Navbar::LINK_CLASSES.
      # :link (not :default) removes the background/border while
      # keeping button padding — plain icon-only nav buttons, not
      # filled buttons. (:strip would remove padding too.)
      assert_html(html, "a.prev_page_link.btn.btn-link.btn-lg")
      assert_html(html, "a.next_page_link.btn.btn-link.btn-lg")
    end

    def test_prev_link_disabled_on_first_page
      html = render_nav(pagination_data: paginated(50, 1))

      assert_html(html, "a.prev_page_link.disabled")
    end

    def test_next_link_disabled_on_last_page
      html = render_nav(pagination_data: paginated(50, 5))

      assert_html(html, "a.next_page_link.disabled")
    end

    def test_prev_and_next_links_enabled_on_middle_page
      html = render_nav(pagination_data: paginated(50, 3))

      assert_html(html, "a.prev_page_link:not(.disabled)")
      assert_html(html, "a.next_page_link:not(.disabled)")
    end

    # No <form> -- the goto input is a free element and "Goto" is a
    # plain link (page-input_controller.js keeps it in sync
    # client-side). MO's suite is Ruby-only, so the Stimulus behavior
    # itself isn't covered here.
    def test_page_input_group_has_correct_structure
      html = render_nav(pagination_data: paginated(50, 2))

      assert_no_html(html, "form.page_input")
      assert_html(
        html, "div.input-group.page-input[data-controller='page-input']",
        count: 1
      )
      # Input should have current page value
      assert_html(html, "input[name='page']", attribute: { value: "2" })
    end

    def test_page_goto_link_points_at_current_page
      html = render_nav(pagination_data: paginated(50, 2))

      assert_html(html, "a[href='/observations?page=2" \
                        "&q%5Bmodel%5D=Observation']")
    end

    def test_page_goto_link_has_translated_tooltip
      html = render_nav(pagination_data: paginated(50, 2))

      assert_html(
        html, "a[data-page-input-target='goToLink'] svg",
        attribute: { title: :goto_page_tooltip.t(number: 2) }
      )
    end

    def test_renders_letter_pagination_when_needed
      pagination_data = ::PaginationData.new(
        number: 1, num_per_page: 10, num_total: 50, number_arg: :page,
        letter_arg: :letter, letter: "A", used_letters: %w[A B C D E]
      )

      html = render_nav(pagination_data: pagination_data)

      assert_includes(html, 'class="paginate pagination_letters flex-bar')
      assert_html(html, "input[name='letter']", attribute: { value: "A" })
      assert_no_html(html, "form.page_input")
      assert_html(
        html, "div.input-group.page-input[data-controller='page-input']"
      )
    end

    def test_letter_goto_link_clears_page_number
      pagination_data = ::PaginationData.new(
        number: 1, num_per_page: 10, num_total: 50, number_arg: :page,
        letter_arg: :letter, letter: "B", used_letters: %w[A B C]
      )

      html = render_nav(pagination_data: pagination_data,
                        request_url: "/observations?page=3&letter=A")

      assert_nested(
        html, parent_selector: "nav.pagination_letters",
              child_selector: "a[href='/observations?letter=B']"
      )
    end

    def test_does_not_render_letter_pagination_when_not_needed
      html = render_nav(pagination_data: paginated(50, 1))

      assert_not_includes(html, "pagination_letters")
    end

    def test_renders_sorter_slot_content
      html = render(build_nav(pagination_data: paginated(50, 1))) do |comp|
        comp.with_sorter do
          view_context.tag.div("Sorter content", class: "test-sorter")
        end
      end

      assert_includes(html, "Sorter content")
      assert_includes(html, "test-sorter")
    end

    def test_pagination_nav_nesting_structure
      html = render_nav(pagination_data: paginated(50, 2))

      assert_nested(html, parent_selector: "nav.pagination_numbers",
                          child_selector: "a.prev_page_link")
      assert_nested(html, parent_selector: "nav.pagination_numbers",
                          child_selector: "div.input-group.page-input")
      assert_nested(html, parent_selector: "nav.pagination_numbers",
                          child_selector: "a.next_page_link")
    end

    def test_renders_nothing_when_pagination_data_nil
      html = render_nav(pagination_data: nil)

      # Should still render the wrapper divs
      assert_includes(html, "pagination-top")
      # But no nav elements
      assert_not_includes(html, "pagination_numbers")
      assert_not_includes(html, "pagination_letters")
    end

    def test_clamps_page_number_when_below_minimum
      html = render_nav(pagination_data: paginated(50, 0))

      # Page input should show 1, not 0
      assert_html(html, "input[name='page']", attribute: { value: "1" })
      assert_html(html, "a.prev_page_link.disabled")
    end

    def test_clamps_page_number_when_above_maximum
      html = render_nav(pagination_data: paginated(50, 99))

      # Page input should show 5 (max page), not 99
      assert_html(html, "input[name='page']", attribute: { value: "5" })
      assert_html(html, "a.next_page_link.disabled")
    end

    def test_pagination_links_include_anchor_when_specified
      html = render_nav(pagination_data: paginated(50, 2), anchor: "results")

      # Prev / next / max-page links should all carry `#results`
      assert_html(html, "a.prev_page_link[href*='#results']")
      assert_html(html, "a.next_page_link[href*='#results']")
      assert_html(
        html,
        "nav.pagination_numbers " \
        "a:not(.prev_page_link):not(.next_page_link)[href*='#results']"
      )
    end

    private

    def paginated(num_total, number, num_per_page: 10)
      ::PaginationData.new(
        number: number, num_per_page: num_per_page,
        num_total: num_total, number_arg: :page
      )
    end

    def build_nav(**overrides)
      Views::Layouts::Header::IndexPaginationNav.new(
        position: :top,
        request_url: @request_url,
        **overrides
      )
    end

    def render_nav(**overrides)
      render(build_nav(**overrides))
    end
  end
end

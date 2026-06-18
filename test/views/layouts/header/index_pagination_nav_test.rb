# frozen_string_literal: true

require("test_helper")

module Views::Layouts
  class Header::IndexPaginationNavTest < ComponentTestCase
    def setup
      super
      @request_url = "/observations?q%5Bmodel%5D=Observation"
      @form_action_url = "http://test.host/observations"
    end

    def test_renders_basic_structure_with_position_top
      html = render_nav(position: :top, pagination_data: paginated(50, 1))

      # Main container has correct position class
      assert_includes(html, 'class="pagination-top navbar-flex mb-2"')

      # Contains two d-flex divs
      assert_html(html, "div.pagination-top > div.d-flex", count: 2)
    end

    def test_renders_basic_structure_with_position_bottom
      html = render_nav(position: :bottom, pagination_data: paginated(50, 1))

      assert_includes(html, 'class="pagination-bottom navbar-flex mb-2"')
    end

    def test_renders_number_pagination_when_multiple_pages
      html = render_nav(pagination_data: paginated(50, 1))

      assert_includes(html, 'class="paginate pagination_numbers navbar-flex')
      assert_includes(html, "prev_page_link")
      assert_includes(html, "next_page_link")
      assert_includes(html, 'class="navbar-form px-0 page_input"')
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

    def test_page_input_form_has_correct_structure
      html = render_nav(pagination_data: paginated(50, 2))

      assert_html(html, "form.page_input",
                  attribute: { action: @form_action_url })
      assert_includes(html, 'data-controller="page-input"')
      assert_nested(
        html, parent_selector: "form.page_input",
              child_selector: "div.input-group.page-input"
      )
      # Input should have current page value
      assert_html(html, "input[name='page']", attribute: { value: "2" })
    end

    # Reads through `q_param(current_query)`: stub current_query with
    # a saved Query whose params include `order_by`, and the hidden
    # fields should match the model + order_by shape.
    def test_renders_q_hidden_fields
      query = ::Query.lookup(:Observation, order_by: :created_at)
      query.save
      stub_current_query(query)

      html = render_nav(pagination_data: paginated(50, 1))

      assert_html(html, "input[type='hidden'][name='q[model]']",
                  attribute: { value: "Observation" })
      assert_html(html, "input[type='hidden'][name='q[order_by]']",
                  attribute: { value: "created_at" })
    end

    # Default current_query (nil) → no q-hidden-fields rendered.
    def test_renders_no_q_hidden_fields_without_current_query
      html = render_nav(pagination_data: paginated(50, 1))

      assert_no_html(html, "input[type='hidden'][name^='q[']")
    end

    def test_renders_letter_pagination_when_needed
      pagination_data = ::PaginationData.new(
        number: 1, num_per_page: 10, num_total: 50, number_arg: :page,
        letter_arg: :letter, letter: "A", used_letters: %w[A B C D E]
      )

      html = render_nav(pagination_data: pagination_data)

      assert_includes(html, 'class="paginate pagination_letters navbar-flex')
      assert_html(html, "input[name='letter']", attribute: { value: "A" })
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
                          child_selector: "form.page_input")
      assert_nested(html, parent_selector: "nav.pagination_numbers",
                          child_selector: "a.next_page_link")
    end

    def test_renders_letter_hidden_field_in_page_form
      pagination_data = ::PaginationData.new(
        number: 1, num_per_page: 10, num_total: 50, number_arg: :page,
        letter_arg: :letter, letter: "B", used_letters: %w[A B C]
      )

      html = render_nav(pagination_data: pagination_data,
                        letter_param: "B")

      assert_nested(
        html, parent_selector: "nav.pagination_numbers form.page_input",
              child_selector: "input[type='hidden'][name='letter'][value='B']"
      )
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
        form_action_url: @form_action_url,
        **overrides
      )
    end

    def render_nav(**overrides)
      render(build_nav(**overrides))
    end

    def stub_current_query(query)
      controller.instance_variable_set(:@query, query)
    end
  end
end

# frozen_string_literal: true

require("test_helper")

class IndexPaginationNavTest < ComponentTestCase
  def setup
    super
    @request_url = "/observations?q%5Bmodel%5D=Observation"
    @form_action_url = "http://test.host/observations"
    @q_params = { model: "Observation" }
  end

  def test_renders_basic_structure_with_position_top
    pagination_data = PaginationData.new(
      number: 1,
      num_per_page: 10,
      num_total: 50,
      number_arg: :page
    )

    html = render(Components::IndexPaginationNav.new(
                    pagination_data: pagination_data,
                    position: :top,
                    request_url: @request_url,
                    form_action_url: @form_action_url,
                    q_params: @q_params
                  ))

    # Main container has correct position class
    assert_includes(html, 'class="pagination-top navbar-flex mb-2"')

    # Contains two d-flex divs
    assert_html(html, "div.pagination-top > div.d-flex", count: 2)
  end

  def test_renders_basic_structure_with_position_bottom
    pagination_data = PaginationData.new(
      number: 1,
      num_per_page: 10,
      num_total: 50,
      number_arg: :page
    )

    html = render(Components::IndexPaginationNav.new(
                    pagination_data: pagination_data,
                    position: :bottom,
                    request_url: @request_url,
                    form_action_url: @form_action_url,
                    q_params: @q_params
                  ))

    assert_includes(html, 'class="pagination-bottom navbar-flex mb-2"')
  end

  def test_renders_number_pagination_when_multiple_pages
    pagination_data = PaginationData.new(
      number: 1,
      num_per_page: 10,
      num_total: 50,
      number_arg: :page
    )

    html = render(Components::IndexPaginationNav.new(
                    pagination_data: pagination_data,
                    position: :top,
                    request_url: @request_url,
                    form_action_url: @form_action_url,
                    q_params: @q_params
                  ))

    # Should have number pagination nav
    assert_includes(html, 'class="paginate pagination_numbers navbar-flex')

    # Should have prev/next page links
    assert_includes(html, "prev_page_link")
    assert_includes(html, "next_page_link")

    # Should have page input form
    assert_includes(html, 'class="navbar-form px-0 page_input"')

    # Should have the max page link (5 pages = 50/10)
    assert_nested(
      html,
      parent_selector: "nav.pagination_numbers",
      child_selector: "a",
      text: "5"
    )
  end

  def test_does_not_render_number_pagination_when_single_page
    pagination_data = PaginationData.new(
      number: 1,
      num_per_page: 10,
      num_total: 5,
      number_arg: :page
    )

    html = render(Components::IndexPaginationNav.new(
                    pagination_data: pagination_data,
                    position: :top,
                    request_url: @request_url,
                    form_action_url: @form_action_url,
                    q_params: @q_params
                  ))

    # Should NOT have number pagination nav
    assert_not_includes(html, "pagination_numbers")
  end

  def test_prev_link_disabled_on_first_page
    pagination_data = PaginationData.new(
      number: 1,
      num_per_page: 10,
      num_total: 50,
      number_arg: :page
    )

    html = render(Components::IndexPaginationNav.new(
                    pagination_data: pagination_data,
                    position: :top,
                    request_url: @request_url,
                    form_action_url: @form_action_url,
                    q_params: @q_params
                  ))

    # Prev link should have disabled class
    assert_html(html, "a.prev_page_link.disabled")
  end

  def test_next_link_disabled_on_last_page
    pagination_data = PaginationData.new(
      number: 5,
      num_per_page: 10,
      num_total: 50,
      number_arg: :page
    )

    html = render(Components::IndexPaginationNav.new(
                    pagination_data: pagination_data,
                    position: :top,
                    request_url: @request_url,
                    form_action_url: @form_action_url,
                    q_params: @q_params
                  ))

    # Next link should have disabled class
    assert_html(html, "a.next_page_link.disabled")
  end

  def test_prev_and_next_links_enabled_on_middle_page
    pagination_data = PaginationData.new(
      number: 3,
      num_per_page: 10,
      num_total: 50,
      number_arg: :page
    )

    html = render(Components::IndexPaginationNav.new(
                    pagination_data: pagination_data,
                    position: :top,
                    request_url: @request_url,
                    form_action_url: @form_action_url,
                    q_params: @q_params
                  ))

    # Prev link should NOT have disabled class
    assert_html(html, "a.prev_page_link:not(.disabled)")

    # Next link should NOT have disabled class
    assert_html(html, "a.next_page_link:not(.disabled)")
  end

  def test_page_input_form_has_correct_structure
    pagination_data = PaginationData.new(
      number: 2,
      num_per_page: 10,
      num_total: 50,
      number_arg: :page
    )

    html = render(Components::IndexPaginationNav.new(
                    pagination_data: pagination_data,
                    position: :top,
                    request_url: @request_url,
                    form_action_url: @form_action_url,
                    q_params: @q_params
                  ))

    # Form should have correct action
    assert_html(html, "form.page_input",
                attribute: { action: @form_action_url })

    # Form should have Stimulus controller data
    assert_includes(html, 'data-controller="page-input"')

    # Form should contain input group
    assert_nested(
      html,
      parent_selector: "form.page_input",
      child_selector: "div.input-group.page-input"
    )

    # Input should have current page value
    assert_html(html, "input[name='page']", attribute: { value: "2" })
  end

  def test_renders_q_hidden_fields
    pagination_data = PaginationData.new(
      number: 1,
      num_per_page: 10,
      num_total: 50,
      number_arg: :page
    )

    html = render(Components::IndexPaginationNav.new(
                    pagination_data: pagination_data,
                    position: :top,
                    request_url: @request_url,
                    form_action_url: @form_action_url,
                    q_params: { model: "Observation", by_user: "1" }
                  ))

    # Should have hidden fields for q params
    assert_html(html, "input[type='hidden'][name='q[model]']",
                attribute: { value: "Observation" })
    assert_html(html, "input[type='hidden'][name='q[by_user]']",
                attribute: { value: "1" })
  end

  def test_renders_letter_pagination_when_needed
    pagination_data = PaginationData.new(
      number: 1,
      num_per_page: 10,
      num_total: 50,
      number_arg: :page,
      letter_arg: :letter,
      letter: "A",
      used_letters: %w[A B C D E]
    )

    html = render(Components::IndexPaginationNav.new(
                    pagination_data: pagination_data,
                    position: :top,
                    request_url: @request_url,
                    form_action_url: @form_action_url,
                    q_params: @q_params
                  ))

    # Should have letter pagination nav
    assert_includes(html, 'class="paginate pagination_letters navbar-flex')

    # Should have letter input
    assert_html(html, "input[name='letter']", attribute: { value: "A" })
  end

  def test_does_not_render_letter_pagination_when_not_needed
    pagination_data = PaginationData.new(
      number: 1,
      num_per_page: 10,
      num_total: 50,
      number_arg: :page
      # No letter_arg, letter, or used_letters
    )

    html = render(Components::IndexPaginationNav.new(
                    pagination_data: pagination_data,
                    position: :top,
                    request_url: @request_url,
                    form_action_url: @form_action_url,
                    q_params: @q_params
                  ))

    # Should NOT have letter pagination nav
    assert_not_includes(html, "pagination_letters")
  end

  def test_renders_sorter_slot_content
    pagination_data = PaginationData.new(
      number: 1,
      num_per_page: 10,
      num_total: 50,
      number_arg: :page
    )

    html = render(Components::IndexPaginationNav.new(
                    pagination_data: pagination_data,
                    position: :top,
                    request_url: @request_url,
                    form_action_url: @form_action_url,
                    q_params: @q_params
                  )) do |component|
      component.with_sorter do
        view_context.tag.div("Sorter content", class: "test-sorter")
      end
    end

    # Sorter content should be in the first d-flex div
    assert_includes(html, "Sorter content")
    assert_includes(html, "test-sorter")
  end

  def test_pagination_nav_nesting_structure
    pagination_data = PaginationData.new(
      number: 2,
      num_per_page: 10,
      num_total: 50,
      number_arg: :page
    )

    html = render(Components::IndexPaginationNav.new(
                    pagination_data: pagination_data,
                    position: :top,
                    request_url: @request_url,
                    form_action_url: @form_action_url,
                    q_params: @q_params
                  ))

    # Verify the nav element contains the expected children
    assert_nested(
      html,
      parent_selector: "nav.pagination_numbers",
      child_selector: "a.prev_page_link"
    )

    assert_nested(
      html,
      parent_selector: "nav.pagination_numbers",
      child_selector: "form.page_input"
    )

    assert_nested(
      html,
      parent_selector: "nav.pagination_numbers",
      child_selector: "a.next_page_link"
    )
  end

  def test_renders_letter_hidden_field_in_page_form
    pagination_data = PaginationData.new(
      number: 1,
      num_per_page: 10,
      num_total: 50,
      number_arg: :page,
      letter_arg: :letter,
      letter: "B",
      used_letters: %w[A B C]
    )

    html = render(Components::IndexPaginationNav.new(
                    pagination_data: pagination_data,
                    position: :top,
                    request_url: @request_url,
                    form_action_url: @form_action_url,
                    q_params: @q_params,
                    letter_param: "B"
                  ))

    # The page input form should have a hidden letter field
    assert_nested(
      html,
      parent_selector: "nav.pagination_numbers form.page_input",
      child_selector: "input[type='hidden'][name='letter'][value='B']"
    )
  end

  def test_renders_nothing_when_pagination_data_nil
    html = render(Components::IndexPaginationNav.new(
                    pagination_data: nil,
                    position: :top,
                    request_url: @request_url,
                    form_action_url: @form_action_url,
                    q_params: @q_params
                  ))

    # Should still render the wrapper divs
    assert_includes(html, "pagination-top")

    # But no nav elements
    assert_not_includes(html, "pagination_numbers")
    assert_not_includes(html, "pagination_letters")
  end

  def test_clamps_page_number_when_below_minimum
    pagination_data = PaginationData.new(
      number: 0,
      num_per_page: 10,
      num_total: 50,
      number_arg: :page
    )

    html = render(Components::IndexPaginationNav.new(
                    pagination_data: pagination_data,
                    position: :top,
                    request_url: @request_url,
                    form_action_url: @form_action_url,
                    q_params: @q_params
                  ))

    # Page input should show 1, not 0
    assert_html(html, "input[name='page']", attribute: { value: "1" })

    # Prev link should be disabled (we're on first page)
    assert_html(html, "a.prev_page_link.disabled")
  end

  def test_clamps_page_number_when_above_maximum
    pagination_data = PaginationData.new(
      number: 99,
      num_per_page: 10,
      num_total: 50,
      number_arg: :page
    )

    html = render(Components::IndexPaginationNav.new(
                    pagination_data: pagination_data,
                    position: :top,
                    request_url: @request_url,
                    form_action_url: @form_action_url,
                    q_params: @q_params
                  ))

    # Page input should show 5 (max page), not 99
    assert_html(html, "input[name='page']", attribute: { value: "5" })

    # Next link should be disabled (we're on last page)
    assert_html(html, "a.next_page_link.disabled")
  end

  def test_pagination_links_include_anchor_when_specified
    pagination_data = PaginationData.new(
      number: 2,
      num_per_page: 10,
      num_total: 50,
      number_arg: :page
    )

    html = render(Components::IndexPaginationNav.new(
                    pagination_data: pagination_data,
                    position: :top,
                    request_url: @request_url,
                    form_action_url: @form_action_url,
                    q_params: @q_params,
                    args: { anchor: "results" }
                  ))

    # Prev link should have anchor (use attribute substring match)
    assert_html(html, "a.prev_page_link[href*='#results']")

    # Next link should have anchor
    assert_html(html, "a.next_page_link[href*='#results']")

    # Max page link should have anchor
    assert_html(
      html,
      "nav.pagination_numbers " \
      "a:not(.prev_page_link):not(.next_page_link)[href*='#results']"
    )
  end
end

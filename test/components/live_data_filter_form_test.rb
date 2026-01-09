# frozen_string_literal: true

require("test_helper")

class LiveDataFilterFormTest < ComponentTestCase
  def test_renders_form_structure
    html = render_filter_form

    # Nav wrapper with flex layout
    assert_html(html, "nav.d-flex.justify-content-between")

    # Form with autosubmit controller
    assert_html(html, "form[action='/test/filter']")
    assert_html(html, "[data-controller='autosubmit']")
    assert_html(html, "[data-turbo-frame='test_frame']")

    # Filter input
    assert_html(html, "input[name='text_filter[starts_with]']")
    assert_html(html, "[data-action='input->autosubmit#submit']")
  end

  def test_renders_prev_next_buttons
    html = render_filter_form(page: 2, total_pages: 5)

    # Both buttons visible
    assert_includes(html, "Prev")
    assert_includes(html, "Next")

    # Prev links to page 1
    assert_html(html, "a[href*='page=1']")
    # Next links to page 3
    assert_html(html, "a[href*='page=3']")
  end

  def test_hides_prev_on_first_page
    html = render_filter_form(page: 1, total_pages: 5)

    # Prev button has opacity-0 class (hidden)
    assert_includes(html, 'class="btn btn-default btn-sm opacity-0"')
    # Check prev link is disabled
    assert_html(html, "a[disabled]", text: "Prev")
  end

  def test_hides_next_on_last_page
    html = render_filter_form(page: 5, total_pages: 5)

    # Next button has opacity-0 class (hidden)
    assert_html(html, "a[disabled]", text: "Next")
  end

  def test_single_page_hides_both_buttons
    html = render_filter_form(page: 1, total_pages: 1)

    # Both buttons have opacity-0
    assert_equal(2, html.scan("opacity-0").count)
  end

  def test_renders_with_custom_placeholder
    html = render_filter_form(placeholder: "Search IPs...")

    assert_html(html, "input[placeholder='Search IPs...']")
  end

  def test_renders_with_custom_param_names
    html = render_filter_form(
      page: 2,
      total_pages: 3,
      page_param: "okay_page",
      filter_param: "okay_filter"
    )

    # Uses custom param names in pagination URLs
    assert_html(html, "a[href*='okay_page=1']")
    assert_html(html, "a[href*='okay_page=3']")

    # NOTE: Form input name comes from FormObject model, not filter_param.
    # filter_param is only used for building pagination URLs
    assert_html(html, "input[name='text_filter[starts_with]']")
  end

  def test_preserves_filter_value_in_pagination_links
    html = render_filter_form(
      page: 2,
      total_pages: 3,
      starts_with: "10.0"
    )

    # Pagination links include the filter value
    assert_includes(html, "text_filter%5Bstarts_with%5D=10.0")
  end

  def test_form_id_derived_from_turbo_frame
    html = render_filter_form(turbo_frame: "blocked_ips_list")

    assert_html(html, "#blocked-ips-list-filter-form")
  end

  private

  def render_filter_form(**opts)
    defaults = {
      page: 1, total_pages: 3, starts_with: nil, placeholder: "Filter...",
      turbo_frame: "test_frame", page_param: "page", filter_param: "text_filter"
    }
    opts = defaults.merge(opts)
    filter = FormObject::TextFilter.new(starts_with: opts[:starts_with])
    render(Components::LiveDataFilterForm.new(
             filter,
             turbo_frame: opts[:turbo_frame],
             page: opts[:page],
             total_pages: opts[:total_pages],
             filter_path: "/test/filter",
             placeholder: opts[:placeholder],
             page_param: opts[:page_param],
             filter_param: opts[:filter_param]
           ))
  end
end

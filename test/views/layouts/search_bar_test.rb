# frozen_string_literal: true

require("test_helper")

class Views::Layouts::SearchBarTest < ComponentTestCase
  def setup
    super
    @user = users(:rolf)
    viewer = @user
    controller.define_singleton_method(:current_user) { viewer }
    stub_session(search_type: "observations")
  end

  def stub_session(search_type:, search_view: nil)
    session = { search_type: search_type, search_view: search_view }
    controller.define_singleton_method(:session) { session }
  end

  # rubocop:disable-next MO/NoCosmeticClassAssertion
  def test_help_toggle_visible_when_type_has_help
    html = render_bar(help_types: [:observations])

    # Rendered as <a> (link) not <button>; href serves as the
    # collapse target (no separate data-target needed).
    assert_html(html,
                "a[data-toggle='collapse']" \
                "[data-search-type-target='helpToggle']" \
                "[href='#search_bar_help']" \
                "[aria-controls='search_bar_help']" \
                "[aria-expanded='false']")
    assert_html(html,
                "a[data-search-type-target='helpToggle'] " \
                "span[aria-label='#{:search_bar_help.t}']")
    assert_html(html,
                "a[data-search-type-target='helpToggle'] svg.mo-icon-info")
    assert_no_html(html,
                   "a[data-search-type-target='helpToggle'].d-none")
    assert_html(html,
                "a[data-search-type-target='helpToggle'].btn.btn-link")
  end

  def test_help_toggle_hidden_when_type_has_no_help
    html = render_bar(help_types: [])

    assert_html(html,
                "a[data-toggle='collapse']" \
                "[data-search-type-target='helpToggle'].d-none")
  end

  # rubocop:disable-next MO/NoCosmeticClassAssertion
  def test_form_toggle_visible_when_type_has_form
    html = render_bar(form_types: [:observations])

    # The wrapper (not the links inside) owns the availability toggle
    # -- see Views::Layouts::SearchBar#render_form_toggle.
    assert_no_html(html, "div[data-search-type-target='formToggle'].d-none")
    # Icon-only link, shown below md.
    assert_html(html,
                "a[data-toggle='collapse']" \
                "[href='#search_nav_form']" \
                "[aria-controls='search_nav_form']" \
                "[aria-expanded='false'].d-md-none")
    assert_html(html,
                "a[href='#search_nav_form'] " \
                "span[aria-label='#{:search_bar_more_options.l}']")
    assert_html(html, "a[href='#search_nav_form'] svg.mo-icon-plus")
    # Icon-only vs. labeled outline-button.
    assert_html(html, "a[href='#search_nav_form'].btn.btn-link")
    assert_html(html,
                "a[data-toggle='collapse'][href='#search_nav_form']" \
                ".btn.btn-outline-default.d-none.d-md-inline-block",
                text: :search_bar_more_options.l)
  end

  def test_form_toggle_hidden_when_type_has_no_form
    html = render_bar(form_types: [])

    assert_html(html, "div[data-search-type-target='formToggle'].d-none")
  end

  def test_advanced_view_starts_open_when_session_prefers_advanced
    stub_session(search_type: "observations", search_view: "advanced")
    html = render_bar(form_types: [:observations])

    assert_html(html, "#search_nav_form.#{EXPANDED}")
    assert_no_html(html, "#search_bar_elements.#{EXPANDED}")
    assert_html(html,
                "a[href='#search_nav_form'][aria-expanded='true']")
  end

  def test_pattern_view_starts_open_by_default
    html = render_bar(form_types: [:observations])

    assert_html(html, "#search_bar_elements.#{EXPANDED}")
    assert_no_html(html, "#search_nav_form.#{EXPANDED}")
    assert_html(html,
                "a[href='#search_nav_form'][aria-expanded='false']")
  end

  # On the search page itself, `on_search_page?` guards both the
  # form-toggle and the advanced-form target out of the render -- the
  # pattern bar must stay expanded regardless of the stored
  # preference, or it would collapse with nothing left to reopen it.
  def test_bar_stays_expanded_on_search_page_even_when_advanced_preferred
    stub_session(search_type: "observations", search_view: "advanced")
    controller.define_singleton_method(:controller_name) { "search" }

    html = render_bar(form_types: [:observations])

    assert_html(html, "#search_bar_elements.#{EXPANDED}")
    assert_no_html(html, "[data-search-type-target='formToggle']")
  end

  # `session[:search_type]` from a query-backed index can hold a
  # type the select has no option for (e.g. `rss_logs` from the
  # Activity Log) -- without a fallback the browser would display
  # the first alphabetical option, "Comments" (#4969).
  def test_type_select_falls_back_to_observations_for_unselectable_type
    stub_session(search_type: "rss_logs")

    html = render_bar

    assert_html(html, "select[name='pattern_search[type]'] " \
                      "option[selected][value='observations']")
  end

  def test_type_select_keeps_selectable_stored_type
    stub_session(search_type: "comments")

    html = render_bar

    assert_html(html, "select[name='pattern_search[type]'] " \
                      "option[selected][value='comments']")
  end

  def test_renders_login_reminder_when_no_user
    controller.define_singleton_method(:current_user) { nil }
    html = render_bar

    assert_html(html, "strong.navbar-text",
                text: :app_login_reminder.t.as_displayed)
    assert_no_html(html, "[data-toggle='collapse']")
  end

  private

  def render_bar(help_types: [:observations], form_types: [:observations])
    render(Views::Layouts::SearchBar.new(
             search_help_types: help_types,
             search_form_types: form_types
           ))
  end
end

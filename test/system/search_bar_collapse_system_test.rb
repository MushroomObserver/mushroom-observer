# frozen_string_literal: true

require("application_system_test_case")

# Regression guard: collapse.js skipped e.preventDefault() when
# data-target was set, so a `Link::CollapseToggle`'s href="#id" let
# Turbo navigate and made the search form disappear. Panel uses
# Button::CollapseToggle (<button>) instead, which can't navigate.
class SearchBarCollapseSystemTest < ApplicationSystemTestCase
  EXPANDED = Components::Collapsible::EXPANDED_CLASS

  # Test the full collapse-toggle lifecycle inside the top-nav turbo
  # search form:
  #   1. Switch top nav to the faceted observations search form.
  #   2. Expand the "detail" panel — collapsed fields become visible.
  #   3. Collapse the panel — form must remain on the page (no reload).
  def test_faceted_search_panel_open_close_stays_on_page
    login!(users(:rolf))
    visit(observations_path)

    # Open the top-nav search bar collapse (starts hidden).
    find("[aria-controls='search_nav']").click
    assert_selector("#search_nav.#{EXPANDED}", wait: 5)

    # Wait for the search-type Stimulus controller to connect and
    # fire the initial async form fetch into #search_nav_form.
    assert_selector("[data-search-type='connected']", wait: 5)

    # Click the "more options" toggle to expand the advanced form --
    # an icon-only link below lg, a labeled button at lg and up, both
    # inside a `[data-search-type-target='formToggle']` wrapper.
    # Capybara's `find` only considers the one currently visible.
    click_link(href: "#search_nav_form")

    # The form content arrives via Turbo stream; wait for the detail
    # panel heading to confirm it is fully loaded.
    assert_selector(
      "#search_nav_form .card",
      text: :search_term_group_detail.t.as_displayed,
      wait: 10
    )

    # Expand the "detail" collapsible panel.
    find("a[aria-controls='observations_detail']").click
    assert_selector("#observations_detail.#{EXPANDED}", wait: 5)

    # Collapse the panel. Before the fix this caused Bootstrap to skip
    # preventDefault (because data-target was set), Turbo then followed
    # href="#observations_detail", and the search form disappeared.
    find("a[aria-controls='observations_detail']").click

    # Form still on the page — no reload.
    assert_selector("#search_nav_form")
    # Panel heading still there.
    assert_selector(
      "#search_nav_form .card",
      text: :search_term_group_detail.t.as_displayed
    )
    # Collapsed pane is closed.
    assert_no_selector("#observations_detail.#{EXPANDED}")
  end
end

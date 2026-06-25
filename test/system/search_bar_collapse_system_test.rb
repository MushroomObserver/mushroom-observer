# frozen_string_literal: true

require("application_system_test_case")

# Regression guard for the panel collapse-toggle bug introduced when
# Panel#render_collapse_icons switched from `link_to("javascript:void(0)")`
# to `Link::CollapseToggle`. Bootstrap 3 collapse.js skips e.preventDefault()
# when `data-target` is set, letting Turbo follow the `href="#id"` — which
# navigated the Turbo frame and made the search form disappear.
# Fix: Panel now uses Button::CollapseToggle (<button>) so no navigation
# can occur regardless of Bootstrap's preventDefault behavior.
class SearchBarCollapseSystemTest < ApplicationSystemTestCase
  # Test the full collapse-toggle lifecycle inside the top-nav turbo
  # search form:
  #   1. Switch top nav to the faceted observations search form.
  #   2. Expand the "detail" panel — collapsed fields become visible.
  #   3. Collapse the panel — form must remain on the page (no reload).
  def test_faceted_search_panel_open_close_stays_on_page
    visit(observations_path)

    # Wait for the search-type Stimulus controller to connect and
    # fire the initial async form fetch into #search_nav_form.
    assert_selector("[data-search-type='connected']", wait: 5)

    # Click the "more options" toggle to expand the advanced form.
    find("[data-search-type-target='formToggle']").click

    # The form content arrives via Turbo stream; wait for the detail
    # panel heading to confirm it is fully loaded.
    assert_selector(
      "#search_nav_form .panel",
      text: :search_term_group_detail.t.as_displayed,
      wait: 10
    )

    # Expand the "detail" collapsible panel.
    find("button[aria-controls='observations_detail']").click
    assert_selector("#observations_detail.in", wait: 5)

    # Collapse the panel. Before the fix this caused Bootstrap to skip
    # preventDefault (because data-target was set), Turbo then followed
    # href="#observations_detail", and the search form disappeared.
    find("button[aria-controls='observations_detail']").click

    # Form still on the page — no reload.
    assert_selector("#search_nav_form")
    # Panel heading still there.
    assert_selector(
      "#search_nav_form .panel",
      text: :search_term_group_detail.t.as_displayed
    )
    # Collapsed pane is closed.
    assert_no_selector("#observations_detail.in")
  end
end

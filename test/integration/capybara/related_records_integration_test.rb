# frozen_string_literal: true

require("test_helper")

class RelatedRecordsIntegrationTest < CapybaraIntegrationTestCase
  # Tests using a "by user" query of the "Show Locations" link on the obs index
  def test_observations_at_location_links
    login

    visit(observations_path(pattern: "user:#{rolf.id}"))
    click_on("Show Locations", match: :first)
    location = locations(:burbank)
    assert_selector("a", text: location.display_name)
    click_link(location.display_name)
    # visit(location_path(location))
    # assert_selector("a[href*='/observations?location=#{location.id}']")
    assert_selector("a", text: :show_location_observations.t)
    click_link(text: :show_location_observations.l)

    assert_match(:OBSERVATIONS.l, page.title, "Wrong page")
    page.find("#filters").assert_text(location.display_name)
    # Be sure we're not getting the "within_locations" scope.
    assert_no_selector("#filters", text: :within_locations.l)

    results = find_all("#results .matrix-box")
    assert_equal(Observation.locations(location).size, results.size)
    assert_selector("a", text: :show_objects.t(type: :location))
    click_on(:show_objects.t(type: :location), match: :first)

    assert_match("Location", page.title, "Wrong page")
    assert_selector("a[href*='/locations/#{location.id}']")
    assert_selector("a", class: "show_location_link_#{location.id}", count: 1)
  end

  # Test for issue #3585: Going to observations after location search with
  # area order should not cause 500 error
  def test_observations_link_from_location_with_box_area_order
    Location.update_box_area_and_center_columns
    login

    # Create a location query with box_area ordering
    query = Query.lookup(:Location, pattern: "California", order_by: :box_area)
    query.save

    # Visit locations index with box_area ordering
    visit(locations_path(q: query.id.alphabetize))

    # Click on a location with observations
    location = locations(:burbank)
    click_link(location.display_name)

    # Click on "Observations at this Location" link
    click_link(text: :show_location_observations.l)

    # Should successfully load observations page without error
    assert_match(:OBSERVATIONS.l, page.title, "Wrong page")
    page.find("#filters").assert_text(location.display_name)

    # Verify we got the observations for this location
    results = find_all("#results .matrix-box")
    assert_equal(Observation.locations(location).size, results.size)
  end
end

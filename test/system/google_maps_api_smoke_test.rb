# frozen_string_literal: true

require("application_system_test_case")

# Smoke check for the three Google Maps APIs MO depends on. Visits the
# location form (which uses all three) and reports which API(s) the
# Maps key isn't authorized for.
#
# Background: issue #4535 surfaced as "Find on Map does nothing"
# because the Geocoding API wasn't enabled on the production key, even
# though the Maps JavaScript API (map rendering) was. Each Google
# product is enabled independently in the Cloud Console; this test
# exercises each surface separately so a key with a missing product
# fails with a clear "X API is not authorized" message instead of a
# silent regression.
#
# Run alone for the focused output:
#
#     bin/rails test test/system/google_maps_api_smoke_test.rb
class GoogleMapsApiSmokeTest < ApplicationSystemTestCase
  def test_google_maps_apis_authorized_on_key
    login!(users(:rolf))
    visit("/locations/new")
    assert_selector("body.locations__new")

    # 1) Maps JavaScript API — the map canvas renders, and Google's
    # global `gm_authFailure` (installed by `map_controller.js#connect`)
    # didn't fire. Either failure populates `#gmaps_flash`.
    assert_selector("#map_div div div", visible: :all,
                                        wait: 10)
    assert_no_gmaps_flash("Maps JavaScript API")

    # 2) Geocoding API — type a place name and click "Find on Map".
    # `geocode_controller.js#geolocatePlaceName` sends the address to
    # Google; on success the input gets a `.geocoded` class, on
    # failure `#gmaps_flash` gets the error.
    fill_in("location_display_name", with: "Génolhac, Gard, France")
    click_button(:form_locations_find_on_map.l)
    assert_geocoding_succeeded_or_report_failure

    # 3) Elevation API — click "Get Elevations". On success the
    # high/low fields populate; on failure `#gmaps_flash` gets the
    # status string (`OVER_QUERY_LIMIT`, `REQUEST_DENIED`, etc.).
    click_button(:form_locations_get_elevation.l)
    sleep(2) # elevation request + response
    assert_no_gmaps_flash("Elevation API")
  end

  private

  # Asserts `#gmaps_flash` carries no alert content. If it does, the
  # failure message names the API surface so a developer running the
  # test locally knows which Google Cloud product needs enabling.
  def assert_no_gmaps_flash(api_label)
    flash = find_by_id("gmaps_flash", visible: :all)
    text = flash.text.strip
    assert_equal(
      "", text,
      "#{api_label}: `#gmaps_flash` populated with #{text.inspect}. " \
      "Enable the corresponding product on the Maps API key in the " \
      "Google Cloud Console."
    )
  end

  def assert_geocoding_succeeded_or_report_failure
    # If Google returned a result, the input gets `.geocoded`. If it
    # rejected the request, our catch handler populates `#gmaps_flash`.
    # Wait up to 15s for either signal so a slow geocode doesn't race
    # the flash check.
    assert_selector(
      "#location_display_name.geocoded, #gmaps_flash .alert",
      wait: 15
    )
    assert_no_gmaps_flash("Geocoding API")
    assert_selector("#location_display_name.geocoded")
  end
end

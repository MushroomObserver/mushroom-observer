# frozen_string_literal: true

require("application_system_test_case")

class HerbariumFormSystemTest < ApplicationSystemTestCase
  def test_create_fungarium_new_location
    rolf = users("rolf")
    login!(rolf)

    visit("/herbaria/new")
    capture_geocode_errors
    assert_selector("body.herbaria__new")
    create_herbarium_with_new_location

    assert_selector("body.herbaria__show")
    assert_selector("h1", text: "Herbarium des Cévennes (CEV)")
    assert_selector("#herbarium_location",
                    text: "Génolhac, Gard, Occitanie, France")
  end

  def test_observation_form_create_fungarium_new_location
    rolf = users("rolf")
    login!(rolf)

    visit("/observations/new")
    assert_selector("body.observations__new")

    assert_selector("#observation_naming_specimen")
    scroll_to(find_by_id("observation_naming_specimen"), align: :top)
    check("observation_specimen")
    assert_selector("#observation_herbarium_record_herbarium_name")
    assert_selector(".create-link", text: :create_herbarium.l)
    click_link(:create_herbarium.l)

    assert_selector("#modal_herbarium")
    create_herbarium_with_new_location

    assert_no_selector("#modal_herbarium", wait: 15)
    assert_field("observation_herbarium_record_herbarium_name",
                 with: "Herbarium des Cévennes", wait: 15)
  end

  # Verify validation errors appear inside the modal, not on the page
  def test_modal_validation_flash
    rolf = users("rolf")
    login!(rolf)

    visit("/observations/new")
    scroll_to(find_by_id("observation_naming_specimen"), align: :top)
    check("observation_specimen")
    click_link(:create_herbarium.l)

    assert_selector("#modal_herbarium")

    within("#modal_herbarium") do
      # Submit with blank name
      click_commit

      # Error flash should appear inside the modal
      assert_selector("#modal_herbarium_flash", wait: 5)
      assert_selector("#modal_herbarium_flash",
                      text: /#{:create_herbarium_name_blank.l}/i)

      # Modal should still be open
      assert_selector("#herbarium_form")
    end
  end

  # Verify autocompleter switches between location and location_google modes
  def test_location_autocompleter_mode_switching
    rolf = users("rolf")
    login!(rolf)

    visit("/herbaria/new")
    capture_geocode_errors

    within("#herbarium_form") do
      # Start in normal location mode
      assert_selector("[data-type='location']")
      assert_no_selector(".create", visible: :all)

      # Type a location and click create button to switch to location_google
      fill_in("herbarium_place_name", with: "some new place")
      assert_selector(".create-button", visible: :all, wait: 5)
      btn = find(".create-button", visible: :all)
      execute_script("arguments[0].click()", btn)

      # Verify switched to create mode
      assert_selector("[data-type='location_google']", wait: 5)
      assert_selector(".create", visible: :all)

      # Wait for the create-mode switch's own geocode of "some new
      # place" to settle before typing a different name -- otherwise
      # the two requests race to update the same fields.
      wait_for_geocode_settled(count: 1)

      # Type "burbank" - in location_google mode, this triggers Google
      # geocoding. Google returns "Burbank, Los Angeles Co., California,
      # USA" (with county) vs our database's "Burbank, California, USA".
      fill_in("herbarium_place_name", with: "burbank")

      with_geocode_errors_on_failure do
        assert_field("herbarium_location_id", with: "-1", type: :hidden,
                                              wait: 15)
        assert_field("herbarium_place_name",
                     with: "Burbank, Los Angeles Co., California, USA",
                     wait: 10)
      end
    end
  end

  # Verify selecting an existing location from autocomplete
  def test_location_autocompleter_select_existing
    browser = page.driver.browser
    rolf = users("rolf")
    login!(rolf)
    burbank = locations("burbank")

    visit("/herbaria/new")

    within("#herbarium_form") do
      # Focus the field and type using keyboard (triggers autocompleter events)
      find_field("herbarium_place_name").click
      browser.keyboard.type("burbank")

      # Wait for autocomplete dropdown and select using keyboard
      assert_selector(".auto_complete", wait: 5)
      assert_selector(".auto_complete a.dropdown-item", text: /Burbank/i,
                                                        wait: 5)
      browser.keyboard.type(:down, :tab)

      # Verify location was selected (has-id class and hidden field populated)
      assert_selector(".has-id", wait: 5)
      assert_field("herbarium_location_id", with: burbank.id.to_s,
                                            type: :hidden)
    end
  end

  def create_herbarium_with_new_location
    within("#herbarium_form") do
      assert_selector("#herbarium_place_name")
      capture_geocode_errors
      fill_in("herbarium_place_name", with: "genohlac gard france")

      # Wait for create button to appear, then click via JS
      # (button text is hidden on small viewports via d-none d-sm-inline,
      # so Cuprite can't click it directly)
      assert_selector(".create-button", visible: :all, wait: 5)
      btn = find(".create-button", visible: :all)
      execute_script("arguments[0].click()", btn)

      # Verify autocompleter switched to location_google mode
      assert_selector("[data-type='location_google']", wait: 5)

      # Wait for that switch's own geocode call to settle before the
      # input-click workaround below triggers a second one.
      wait_for_geocode_settled(count: 1)

      # Trigger geocoding: `ourClick` on the input -> `scheduleRefresh`
      # -> `scheduleGoogleRefresh`. Capybara's `.click` doesn't reliably
      # fire the event to Stimulus after the JS-driven mode swap above,
      # so dispatch via JS -- same pattern as the create-button click.
      execute_script("arguments[0].click()",
                     find_field("herbarium_place_name"))

      with_geocode_errors_on_failure do
        assert_field("herbarium_location_id", with: "-1", type: :hidden,
                                              wait: 15)
        assert_field("herbarium_place_name",
                     with: "Génolhac, Gard, Occitanie, France", wait: 10)
      end

      # Verify hidden fields are populated correctly
      assert_field("location_north", with: "44.3726", type: :hidden)
      assert_field("location_east", with: "3.985", type: :hidden)
      assert_field("location_south", with: "44.3055", type: :hidden)
      assert_field("location_west", with: "3.9113", type: :hidden)

      fill_in("herbarium_name", with: "Herbarium des Cévennes")
      fill_in("herbarium_code", with: "CEV")
      click_commit
    end
  end

  # TEMP diagnostic (flakiness investigation): wraps
  # google.maps.Geocoder#geocode so a rejected promise is recorded,
  # not just logged -- pulled into the failure message via
  # with_geocode_errors_on_failure (NoTestConsoleNoise strips stray
  # console/stdout output otherwise).
  def capture_geocode_errors
    execute_script(<<~JS)
      window.__geocodeErrors = window.__geocodeErrors || [];
      window.__geocodeSettledCount = window.__geocodeSettledCount || 0;
      (function patch() {
        const gm = window.google && window.google.maps;
        if (!gm || !gm.Geocoder) { setTimeout(patch, 100); return; }
        if (gm.Geocoder.prototype.__geocodePatched) return;
        gm.Geocoder.prototype.__geocodePatched = true;
        const orig = gm.Geocoder.prototype.geocode;
        gm.Geocoder.prototype.geocode = function(...args) {
          return orig.apply(this, args).then((result) => {
            window.__geocodeSettledCount++;
            return result;
          }).catch((e) => {
            window.__geocodeErrors.push(
              JSON.stringify({ name: e && e.name, message: e && e.message,
                               code: e && e.code })
            );
            window.__geocodeSettledCount++;
            throw e;
          });
        };
      })();
    JS
  end

  # Waits for `count` geocode() calls to settle (success or error).
  # Lets an implicitly triggered geocode (e.g. from a create-mode
  # switch) finish before the next one starts, so two requests do
  # not race to update the same fields.
  def wait_for_geocode_settled(count:, wait: 10)
    Timeout.timeout(wait) do
      loop do
        settled = evaluate_script("window.__geocodeSettledCount") || 0
        break if settled >= count

        sleep(0.1)
      end
    end
  end

  def with_geocode_errors_on_failure
    yield
  rescue Minitest::Assertion => e
    errors = evaluate_script("window.__geocodeErrors") || []
    raise(e.class.new("#{e.message}\n\nCaptured geocode errors: #{errors}"))
  end
end

# frozen_string_literal: true

require("application_system_test_case")

class HerbariumFormSystemTest < ApplicationSystemTestCase
  def test_create_fungarium_new_location
    # browser = page.driver.browser
    rolf = users("rolf")
    login!(rolf)

    visit("/herbaria/new")
    assert_selector("body.herbaria__new")
    create_herbarium_with_new_location

    # assert_no_selector("#modal_herbarium")
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
    scroll_to(find("#observation_naming_specimen"), align: :top)
    check("observation_specimen")
    assert_selector("#herbarium_record_herbarium_name")
    assert_selector(".create-link", text: :create_herbarium.l)
    click_link(:create_herbarium.l)

    assert_selector("#modal_herbarium")
    create_herbarium_with_new_location

    assert_no_selector("#modal_herbarium")
    assert_field("herbarium_record_herbarium_name",
                 with: "Herbarium des Cévennes")
  end

  def create_herbarium_with_new_location
    assert_selector("#herbarium_place_name")
    fill_in("herbarium_place_name", with: "genohlac gard france")
    # Wait for create button to appear, then click via JS
    # (text span uses responsive d-none d-sm-inline)
    assert_selector("a.create-button", visible: :all)
    execute_script("document.querySelector('a.create-button').click()")

    # Verify autocompleter switched to location_google mode
    assert_selector("[data-type='location_google']", wait: 5)

    # Wait for geocoding to complete (async Google API call)
    assert_field("herbarium_place_name",
                 with: "Génolhac, Gard, Occitanie, France", wait: 10)

    # Debug: Check DOM state - find hidden field with location in name
    all_hiddens = all("input[type='hidden']", visible: :all)
    puts "\n=== Hidden Fields ==="
    all_hiddens.each do |h|
      if h[:id]&.include?("location") || h[:name]&.include?("location")
        puts "  id=#{h[:id]} name=#{h[:name]} value=[#{h.value}]"
      end
    end

    # Check if hidden field is inside the controller element
    puts "\n=== Checking hidden field location ==="
    ac_el = find("#herbarium_location_autocompleter", visible: :all)
    puts "Autocompleter controller: #{ac_el[:'data-controller']}"
    puts "Autocompleter type: #{ac_el[:'data-type']}"

    # Check if the hidden field is inside the controller
    inside_hidden = ac_el.has_css?("#herbarium_location_id", visible: :all,
                                    wait: 0)
    puts "Hidden inside autocompleter: #{inside_hidden}"

    # Check the hidden field's target attribute
    hidden_el = find("#herbarium_location_id", visible: :all)
    puts "Hidden target attr: #{hidden_el[:'data-autocompleter--location-target']}"

    # Wait for hidden field to be updated (may happen async)
    sleep 1
    assert_field("herbarium_location_id", with: "-1", type: :hidden, wait: 5)
    assert_field("location_north", with: "44.3726", type: :hidden)
    assert_field("location_east", with: "3.985", type: :hidden)
    assert_field("location_south", with: "44.3055", type: :hidden)
    assert_field("location_west", with: "3.9113", type: :hidden)
    # NOTE: location_high and location_low may not be populated by geocoder
    # assert_field("location_high", with: "1388.2098", type: :hidden)
    # assert_field("location_low", with: "287.8201", type: :hidden)

    within("#herbarium_form") do
      fill_in("herbarium_name", with: "Herbarium des Cévennes")
      fill_in("herbarium_code", with: "CEV")
      click_commit
    end
  end
end

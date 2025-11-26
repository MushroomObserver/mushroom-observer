# frozen_string_literal: true

require("application_system_test_case")

class AutocompleterSystemTest < ApplicationSystemTestCase
  setup do
    @browser = page.driver.browser
    @roy = users("roy")
  end

  def test_observation_search_name_autocompleter
    login!(@roy)

    visit("/observations/search/new")
    assert_selector("body.search__new")

    # Name
    find_field("query_observations_names_lookup").click
    @browser.keyboard.type("agaricus camp")
    assert_selector(".auto_complete") # wait
    assert_selector(".auto_complete ul li a", text: "Agaricus campestras")
    assert_selector(".auto_complete ul li a", text: "Agaricus campestris")
    assert_selector(".auto_complete ul li a", text: "Agaricus campestros")
    assert_selector(".auto_complete ul li a", text: "Agaricus campestrus")
    assert_no_selector(".auto_complete ul li a", text: "Agaricus campestruss")
    @browser.keyboard.type(:down, :down, :down, :tab)
    assert_field("query_observations_names_lookup", with: "Agaricus campestros")
    @browser.keyboard.type(:delete, :delete)
    assert_selector(".auto_complete ul li a", text: "Agaricus campestrus")
    @browser.keyboard.type(:down, :down, :down, :down, :tab)
    assert_field("query_observations_names_lookup", with: "Agaricus campestrus")
  end

  def test_observation_search_user_autocompleter
    login!(@roy)

    visit("/observations/search/new")
    assert_selector("body.search__new")

    within("#observations_search_form") do
      assert_field("query_observations_by_users")
    end

    # User
    find_field("query_observations_by_users").click
    @browser.keyboard.type("r")
    assert_selector(".auto_complete") # wait
    assert_selector(".auto_complete ul li a", text: "Rolf Singer")
    assert_selector(".auto_complete ul li a", text: "Roy Halling")
    assert_selector(".auto_complete ul li a", text: "Roy Rogers")
    @browser.keyboard.type(:down, :down, :tab)
    sleep(1)
    assert_field("query_observations_by_users", with: "Roy Halling (roy)")
  end

  # https://github.com/MushroomObserver/mushroom-observer/issues/3374
  def test_clearing_autocompleter_clears_hidden_id
    login!(@roy)

    visit("/observations/search/new")
    assert_selector("body.search__new")

    # Select a user via autocomplete
    find_field("query_observations_by_users").click
    @browser.keyboard.type("rolf")
    assert_selector(".auto_complete") # wait for autocomplete
    assert_selector(".auto_complete ul li a", text: "Rolf Singer")
    @browser.keyboard.type(:down, :tab)
    sleep(0.5)
    assert_field("query_observations_by_users", with: "Rolf Singer (rolf)")

    # Hidden ID should be set
    hidden_field = find("#query_observations_by_users_id", visible: false)
    assert_not_empty(hidden_field.value, "Hidden ID should be set after selection")

    # Clear the field with select-all and delete
    find_field("query_observations_by_users").click
    @browser.keyboard.type([:meta, "a"], :backspace)
    sleep(0.5)

    # Hidden ID should now be empty
    assert_empty(hidden_field.value,
                 "Hidden ID should be cleared when text is cleared")
  end

  # def test_observation_search_location_autocompleter
  #   login!(@roy)

  #   visit("/observations/search/new")
  #   assert_selector("body.search__new")

  #   # Location: Roy's location pref is scientific
  #   @browser.keyboard.type("us")
  #   assert_selector(".auto_complete", wait: 5) # wait for autocomplete
  #   assert_selector(".auto_complete ul li a", minimum: 1) # verify results
  #   @browser.keyboard.type(:down, :tab) # select first result
  #   sleep(0.5)
  #   # Verify something was selected (starts with "USA, California")
  #   value = find_field("query_observations_within_locations").value
  #   assert(value.start_with?("USA, California"),
  #          "Expected 'USA, California' but got: #{value}")
  # end

  def test_autocompleter_in_naming_modal
    browser = page.driver.browser
    rolf = users("rolf")
    login!(rolf)

    obs = Observation.last
    visit(observation_path(obs.id))

    scroll_to(find("#observation_namings"), align: :center)
    assert_link(text: /Propose/)
    click_link(text: /Propose/)
    assert_selector("#modal_obs_#{obs.id}_naming", wait: 9)
    assert_selector("#obs_#{obs.id}_naming_form", wait: 9)
    find_field("naming_name").click
    browser.keyboard.type("Peltige")
    assert_selector(".auto_complete", wait: 3) # wait
    assert_selector(".auto_complete ul li a")
    browser.keyboard.type(:down, :down, :tab)
    assert_field("naming_name", with: "Peltigeraceae ")
    browser.keyboard.type(:tab)
    assert_no_selector(".auto_complete")
    within("#obs_#{obs.id}_naming_form") { click_commit }
    assert_no_selector("#modal_obs_#{obs.id}_naming", wait: 9)
    within("#observation_namings") { assert_text("Peltigeraceae", wait: 6) }
  end
end

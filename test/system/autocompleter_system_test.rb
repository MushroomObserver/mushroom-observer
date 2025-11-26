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

  # ---------------------------------------------------------------
  #  Multi-value autocompleter tests
  #  Test that textarea autocompleters can accept multiple values
  # ---------------------------------------------------------------

  def test_multi_value_name_autocompleter
    login!(@roy)
    visit("/observations/search/new")
    assert_selector("body.search__new")

    field = find_field("query_observations_names_lookup")
    field.click

    # Type first name and select
    @browser.keyboard.type("agaricus camp")
    assert_selector(".auto_complete ul li a", text: "Agaricus campestris")
    @browser.keyboard.type(:down, :tab)
    # Should have selected a name
    value = field.value
    assert_match(/Agaricus/, value)

    # Wait for menu to close (has 0.5s delay), then add newline
    sleep(0.6)
    @browser.keyboard.type(:enter)
    @browser.keyboard.type("coprinus")
    assert_selector(".auto_complete ul li a", text: "Coprinus comatus", wait: 3)
    @browser.keyboard.type(:down, :tab)

    # Verify both names are in the textarea, separated by newline
    final_value = field.value
    assert_match(/Agaricus/, final_value, "First name should be present")
    assert_match(/Coprinus/, final_value, "Second name should be present")
    assert_match(/\n/, final_value, "Names should be separated by newline")
  end

  def test_multi_value_user_autocompleter
    login!(@roy)
    visit("/observations/search/new")
    assert_selector("body.search__new")

    field = find_field("query_observations_by_users")
    field.click

    # Type first user and select
    @browser.keyboard.type("rolf")
    assert_selector(".auto_complete ul li a", text: "Rolf Singer")
    @browser.keyboard.type(:down, :tab)
    value = field.value
    assert_match(/Rolf/, value)

    # Wait for menu to close (has 0.5s delay), then add newline
    sleep(0.6)
    @browser.keyboard.type(:enter)
    @browser.keyboard.type("mary")
    assert_selector(".auto_complete ul li a", text: "Mary Newbie", wait: 3)
    @browser.keyboard.type(:down, :tab)

    # Verify both users are in the textarea
    final_value = field.value
    assert_match(/Rolf/, final_value, "First user should be present")
    assert_match(/Mary/, final_value, "Second user should be present")
    assert_match(/\n/, final_value, "Users should be separated by newline")
  end

  def test_multi_value_project_autocompleter
    login!(@roy)
    visit("/observations/search/new")
    assert_selector("body.search__new")

    field = find_field("query_observations_projects")
    field.click

    # Type first project and select
    @browser.keyboard.type("bolete")
    assert_selector(".auto_complete ul li a", text: "Bolete Project")
    @browser.keyboard.type(:down, :tab)
    value = field.value
    assert_match(/Bolete/, value)

    # Wait for menu to close (has 0.5s delay), then add newline
    sleep(0.6)
    @browser.keyboard.type(:enter)
    @browser.keyboard.type("eol")
    assert_selector(".auto_complete ul li a", text: "EOL Project", wait: 3)
    @browser.keyboard.type(:down, :tab)

    # Verify both projects are in the textarea
    final_value = field.value
    assert_match(/Bolete/, final_value, "First project should be present")
    assert_match(/EOL/, final_value, "Second project should be present")
    assert_match(/\n/, final_value, "Projects should be separated by newline")
  end

  def test_multi_value_location_autocompleter
    login!(@roy)
    visit("/observations/search/new")
    assert_selector("body.search__new")

    field = find_field("query_observations_within_locations")
    field.click

    # Type first location and select (Roy's preference is scientific format)
    @browser.keyboard.type("burbank")
    assert_selector(".auto_complete ul li a", text: /Burbank/i, wait: 3)
    @browser.keyboard.type(:down, :tab)
    value = field.value
    assert_match(/Burbank/i, value)

    # Wait for menu to close (has 0.5s delay), then add newline
    sleep(0.6)
    @browser.keyboard.type(:enter)
    @browser.keyboard.type("albion")
    assert_selector(".auto_complete ul li a", text: /Albion/i, wait: 3)
    @browser.keyboard.type(:down, :tab)

    # Verify both locations are in the textarea
    final_value = field.value
    assert_match(/Burbank/i, final_value, "First location should be present")
    assert_match(/Albion/i, final_value, "Second location should be present")
    assert_match(/\n/, final_value, "Locations should be separated by newline")
  end

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

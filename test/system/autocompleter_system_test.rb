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

    # Test that nested modifier fields (synonyms, subtaxa) appear when typing
    # The collapse div should be visible now that a name is entered
    collapse_selector = "[data-autocompleter--name-target='collapseFields']"
    assert_selector(collapse_selector, visible: true)
    # Should contain the include_synonyms select field
    within(collapse_selector) do
      assert_selector("select[name*='include_synonyms']")
    end
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
    # Capybara's assert_field waits for the value to appear
    assert_field("query_observations_by_users", with: "Rolf Singer (rolf)")

    # Hidden ID should be set - wait for it to have a non-empty value
    hidden_field = find("#query_observations_by_users_id", visible: false)
    assert(hidden_field.value.present?,
           "Hidden ID should be set after selection")

    # Clear the field - use Capybara's cross-platform method
    fill_in("query_observations_by_users", with: "")

    # Hidden ID should now be empty (use waiting matcher)
    assert_field("query_observations_by_users_id", type: :hidden, with: "")
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

  def test_observation_search_region_autocompleter
    login!(@roy)

    visit("/observations/search/new")
    assert_selector("body.search__new")

    # Expand the Location panel to reveal the region field
    find("[data-target='#observations_location']").click
    assert_selector("#observations_location.in", wait: 3)

    # Region autocompleter should show matches as user types
    # (no trailing space required - that was a bug we fixed)
    find_field("query_observations_region").click
    @browser.keyboard.type("calif")
    assert_selector(".auto_complete", wait: 5) # wait for autocomplete
    assert_selector(".auto_complete ul li a", text: /California/i, wait: 3)
    @browser.keyboard.type(:down, :tab)
    assert_field("query_observations_region", with: /California/i)
  end

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

  # ---------------------------------------------------------------
  #  Autocompleter indicator tests
  #  Test that the green checkmark appears when values are selected
  # ---------------------------------------------------------------

  def test_multi_value_autocompleter_shows_checkmark_after_selections
    login!(@roy)

    visit("/observations/search/new")
    assert_selector("body.search__new")

    field = find_field("query_observations_by_users")
    # Find the autocompleter wrapper by going up from the field
    autocompleter = field.ancestor(".autocompleter")

    # Select first user
    field.click
    @browser.keyboard.type("rolf")
    assert_selector(".auto_complete ul li a", text: "Rolf Singer", wait: 5)
    @browser.keyboard.type(:down, :tab)
    assert_field("query_observations_by_users", with: /Rolf/)

    # Wait for menu to close, then add second user
    sleep(0.6)
    @browser.keyboard.type(:enter)
    @browser.keyboard.type("mary")
    assert_selector(".auto_complete ul li a", text: "Mary Newbie", wait: 5)
    @browser.keyboard.type(:down, :tab)

    # Wait for menu to close, then add third user
    sleep(0.6)
    @browser.keyboard.type(:enter)
    @browser.keyboard.type("dick")
    assert_selector(".auto_complete ul li a", text: "Tricky Dick", wait: 5)
    @browser.keyboard.type(:down, :tab)

    # Verify all three users are in the field
    final_value = field.value
    assert_match(/Rolf/, final_value, "First user should be present")
    assert_match(/Mary/, final_value, "Second user should be present")
    assert_match(/Tricky Dick/, final_value, "Third user should be present")

    # Hidden IDs should have all three
    hidden_field = find("#query_observations_by_users_id", visible: false)
    ids = hidden_field.value.split(",")
    assert_equal(3, ids.length, "Should have 3 IDs in hidden field")

    # Checkmark should be visible
    within(autocompleter) do
      indicator = find(".has-id-indicator", visible: :all)
      style = indicator.style("display")
      assert_equal("inline-block", style["display"],
                   "Checkmark should be visible after multiple selections")
    end
  end

  # ---------------------------------------------------------------
  #  Pasted multi-value autocompleter tests
  #  Test that pasting multiple values matches IDs and shows checkmark
  # ---------------------------------------------------------------

  def test_pasted_user_names_get_matching_ids
    login!(@roy)

    visit("/observations/search/new")
    assert_selector("body.search__new")

    # Get user names from fixtures
    rolf = users(:rolf)
    mary = users(:mary)
    dick = users(:dick)

    # Prepare the pasted text (user names separated by newlines)
    pasted_text = [
      "Rolf Singer (rolf)",
      "Mary Newbie (mary)",
      "Tricky Dick (dick)"
    ].join("\n")

    # Fill the field with the pasted text (simulates paste)
    field = find_field("query_observations_by_users")
    field.fill_in(with: pasted_text)

    # Trigger blur to process the pasted values
    field.send_keys(:tab)

    # Wait for staggered fetch requests: 0ms, 450ms, 900ms for 3 users
    hidden_field = find("#query_observations_by_users_id", visible: false)

    # Poll for IDs to appear (up to 5 seconds)
    ids = []
    10.times do
      sleep(0.5)
      ids = hidden_field.value.split(",").map(&:to_i).reject(&:zero?)
      break if ids.length >= 3
    end

    assert_includes(ids, rolf.id, "Rolf's ID should be in hidden field")
    assert_includes(ids, mary.id, "Mary's ID should be in hidden field")
    assert_includes(ids, dick.id, "Dick's ID should be in hidden field")

    # Checkmark should be visible
    autocompleter = field.ancestor(".autocompleter")
    within(autocompleter) do
      indicator = find(".has-id-indicator", visible: :all)
      style = indicator.style("display")
      assert_equal("inline-block", style["display"],
                   "Checkmark should be visible after pasting matching names")
    end
  end

  # ---------------------------------------------------------------
  #  Prefilled autocompleter indicator tests
  #  Test that the green checkmark appears for prefilled values
  # ---------------------------------------------------------------

  def test_prefilled_autocompleter_shows_checkmark
    login!(@roy)

    # Get project IDs from fixtures
    project1 = projects(:bolete_project)
    project2 = projects(:eol_project)
    project3 = projects(:one_genus_two_species_project)

    # Create query and get q_param (no need to save)
    query = Query.lookup(:Observation,
                         projects: [project1.id, project2.id, project3.id])
    url_params = { q: query.q_param }.to_query

    # Visit search form with the q param to prefill
    visit("/observations/search/new?#{url_params}")
    assert_selector("body.search__new")

    # The textarea should have the project names
    field = find_field("query_observations_projects")
    assert_match(/Bolete/, field.value)

    # Hidden field should have all 3 IDs
    hidden_field = find("#query_observations_projects_id", visible: false)
    ids = hidden_field.value.split(",")
    assert_equal(3, ids.length, "Should have 3 IDs prefilled")

    # Checkmark should be visible
    autocompleter = field.ancestor(".autocompleter")
    within(autocompleter) do
      indicator = find(".has-id-indicator", visible: :all)
      style = indicator.style("display")
      assert_equal("inline-block", style["display"],
                   "Checkmark should be visible for prefilled values")
    end
  end

  # ---------------------------------------------------------------
  #  Species List autocompleter test
  #  Test the "Add or Remove Observations from List" form
  #  This uses a species_list type autocompleter which requires
  #  underscore-to-hyphen conversion in the Stimulus controller name
  # ---------------------------------------------------------------

  def test_species_list_autocompleter_in_add_remove_form
    rolf = users(:rolf)
    login!(rolf)

    # Get an observation query to work with
    query = Query.lookup(:Observation, by_users: rolf.id)
    q_param = query.q_param

    # Visit the "Add or Remove Observations" form
    visit("/species_lists/observations/edit?q=#{q_param}")
    assert_selector("#species_list_observations_form")

    # The species_list autocompleter should work
    field = find_field("species_list")
    field.click
    @browser.keyboard.type("query")
    assert_selector(".auto_complete", wait: 5)
    assert_selector(".auto_complete ul li a", text: /Query/i, wait: 3)
    @browser.keyboard.type(:down, :tab)

    # Should have selected a species list
    assert_field("species_list", with: /Query/i)
  end
end

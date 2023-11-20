# frozen_string_literal: true

require("application_system_test_case")

class AutocompleterSystemTest < ApplicationSystemTestCase
  def test_advanced_search_autocompleters
    browser = page.driver.browser
    roy = users("roy")
    login!(roy)

    visit("/search/advanced")

    assert_selector("body.search__advanced")

    within("#advanced_search_form") do
      assert_field("search_name")
      assert_field("search_user")
      assert_field("search_location")
      assert_field("content_filter_region")
      assert_field("content_filter_clade")
    end

    # Name
    find_field("search_name").click
    browser.keyboard.type("agaricus camp")
    assert_selector(".auto_complete") # wait
    assert_selector(".auto_complete ul li", text: "Agaricus campestras")
    assert_selector(".auto_complete ul li", text: "Agaricus campestris")
    assert_selector(".auto_complete ul li", text: "Agaricus campestros")
    assert_selector(".auto_complete ul li", text: "Agaricus campestrus")
    assert_no_selector(".auto_complete ul li", text: "Agaricus campestruss")
    browser.keyboard.type(:down, :down, :down, :tab)
    assert_field("search_name", with: "Agaricus campestros")
    browser.keyboard.type(:delete, :delete)
    assert_selector(".auto_complete ul li", text: "Agaricus campestrus")
    browser.keyboard.type(:down, :down, :down, :down, :tab)
    assert_field("search_name", with: "Agaricus campestrus")

    # User
    find_field("search_user").click
    browser.keyboard.type("r")
    assert_selector(".auto_complete") # wait
    assert_selector(".auto_complete ul li", text: "Rolf Singer")
    assert_selector(".auto_complete ul li", text: "Roy Halling")
    assert_selector(".auto_complete ul li", text: "Roy Rogers")
    browser.keyboard.type(:down, :down, :tab)
    sleep(1)
    assert_field("search_user", with: "roy <Roy Halling>")

    # Location: Roy's location pref is scientific
    find_field("search_location").click
    browser.keyboard.type("USA, Califo")
    assert_selector(".auto_complete") # wait
    assert_selector(".auto_complete ul li", count: 10)
    assert_selector(
      ".auto_complete ul li",
      text: "Point Reyes National Seashore"
    )
    browser.keyboard.type(:down, :down, :down, :down, :down, :down, :tab)
    sleep(1)
    assert_field(
      "search_location",
      with: "USA, California, Marin Co., Point Reyes National Seashore"
    )

    # Clade
    find("#content_filter_clade").click
    browser.keyboard.type("Agari")
    assert_selector(".auto_complete") # wait
    assert_selector(".auto_complete ul li")
    browser.keyboard.type(:down, :tab)
    sleep(1)
    assert_field("content_filter_clade", with: "Agaricaceae")

    # Region
    find("#content_filter_region").click
    browser.keyboard.type("USA, Calif")
    assert_selector(".auto_complete") # wait
    # assert_selector(".auto_complete ul li", count: 10)
    browser.keyboard.type(:down, :tab)
    # sleep(1)
    assert_field("content_filter_region", with: "USA, California")

    # OR separator not working yet.
    # browser.keyboard.type(:right, :space, "OR", :space, "USA, Mas")
    # assert_selector(".auto_complete ul li", count: 10)
  end

  def test_autocompleter_in_naming_modal
    browser = page.driver.browser
    rolf = users("rolf")
    login!(rolf)

    visit(observation_path(Observation.last.id))

    click_on("Propose")
    assert_selector("#modal_naming")
    assert_selector("#naming_form")
    find_field("naming_name").click
    browser.keyboard.type("Peltige")
    assert_selector(".auto_complete") # wait
    assert_selector(".auto_complete ul li")
    browser.keyboard.type(:down, :down, :tab)
    assert_field("naming_name", with: "Peltigeraceae ")
    within("#naming_form") { click_commit }
    within("#namings_table") { assert_text("Peltigeraceae") }
  end
end

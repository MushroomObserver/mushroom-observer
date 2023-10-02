# frozen_string_literal: true

require("application_system_test_case")

class AutocompleterSystemTest < ApplicationSystemTestCase
  def test_advanced_search_autocompleters
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

      # Name
      fill_in("search_name", with: "agaricus camp")
      assert_selector(".auto_complete ul li", text: "Agaricus campestras")
      assert_selector(".auto_complete ul li", text: "Agaricus campestris")
      assert_selector(".auto_complete ul li", text: "Agaricus campestros")
      assert_selector(".auto_complete ul li", text: "Agaricus campestrus")
      assert_no_selector(".auto_complete ul li", text: "Agaricus campestruss")
      send_keys(:down, :down, :down, :tab)
      assert_field("search_name", with: "Agaricus campestros")
      send_keys(:delete, :delete)
      assert_selector(".auto_complete ul li", text: "Agaricus campestrus")
      send_keys(:down, :down, :down, :down, :tab)
      assert_field("search_name", with: "Agaricus campestrus")

      # User
      fill_in("search_user", with: "r")
      assert_selector(".auto_complete ul li", text: "Rolf Singer")
      assert_selector(".auto_complete ul li", text: "Roy Halling")
      assert_selector(".auto_complete ul li", text: "Roy Rogers")
      send_keys(:down, :down, :tab)
      assert_field("search_user", with: "roy <Roy Halling>")

      # Location: Roy's location pref is scientific
      fill_in("search_location", with: "USA, Califo")
      assert_selector(".auto_complete ul li", count: 10)
      assert_selector(
        ".auto_complete ul li",
        text: "Point Reyes National Seashore"
      )
      send_keys(:down, :down, :down, :down, :down, :down, :tab)
      assert_field(
        "search_location",
        with: "USA, California, Marin Co., Point Reyes National Seashore"
      )

      # Region
      fill_in("content_filter_region", with: "USA, Calif")
      sleep(1)
      assert_selector(".auto_complete ul li", count: 10)
      send_keys(:down, :tab)
      assert_field("content_filter_region", with: "USA, California")

      # OR separator not working yet.
      # send_keys(:right, :space, "OR", :space, "USA, Mas")
      # assert_selector(".auto_complete ul li", count: 10)

      # Clade
      fill_in("content_filter_clade", with: "Agari")
      sleep(1)
      assert_selector(".auto_complete ul li")
      send_keys(:down, :tab)
      assert_field("content_filter_clade", with: "Agaricaceae")
    end
  end
end

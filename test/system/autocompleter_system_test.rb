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

      fill_in("search_name", with: "agaricus ca")
      assert_selector(".auto_complete ul li", text: "Agaricus campestras")
      assert_selector(".auto_complete ul li", text: "Agaricus campestris")
      assert_selector(".auto_complete ul li", text: "Agaricus campestros")
      assert_selector(".auto_complete ul li", text: "Agaricus campestrus")
      assert_no_selector(".auto_complete ul li", text: "Agaricus campestruss")
    end
    binding.break
  end
end

# frozen_string_literal: true

require("application_system_test_case")

class AutocompleterSystemTest < ApplicationSystemTestCase
  roy = users("roy")
  login!(roy)

  assert_link("Advanced search")
  click_on("Advanced search")

  assert_selector("body.search__advanced")

  within("#advanced_search_form") do
    assert_field("search_name")
    assert_field("search_user")
    assert_field("search_location")
    assert_field("content_filter_region")
    assert_field("content_filter_clade")
  end
end

# frozen_string_literal: true

require "test_helper"

# Tests which supplement QueryTest
class QuerySupplementalTest < IntegrationTestCase
  # Test deserialization of non-ascii characters
  # Some page titles include smart single quotes
  #               `             and ’
  # serialized as %26%238216%3B and %26%238217%3B
  # displayed as  &#8216        and &#8217;
  # after deserialization.
  def test_deserialize
    pattern = "Agaricus campestris"

    visit("/")
    fill_in("search_pattern", with: pattern)
    page.select("Comments", from: :search_type)
    click_button("Search")
    title = page.find_by_id("title")

    title.assert_text("‘#{pattern}’")
  end
end

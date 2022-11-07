# frozen_string_literal: true

require("test_helper")

# Tests which supplement QueryTest
class QuerySupplementalTest < CapybaraIntegrationTestCase
  # Test deserialization of non-ascii characters
  # Observation and Show Location title include
  #               `             and ’
  # as            &#8216        and &#8217;
  # serialized as %26%238216%3B and %26%238217%3B
  # They are deserialized and displayed as pat of Map Locations title.
  def test_deserialize
    obs = observations(:boletus_edulis_obs)

    login
    fill_in("search_pattern", with: obs.name.text_name)
    page.select("Observations", from: :search_type)
    click_button("Search")
    click_link("Show Locations")
    click_link("Map Locations")

    title = page.find("#title")
    title.assert_text("‘#{obs.name.text_name}’")
  end
end

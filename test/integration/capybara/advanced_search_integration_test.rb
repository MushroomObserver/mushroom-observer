# frozen_string_literal: true

require("test_helper")

class AdvancedSearchIntegrationTest < CapybaraIntegrationTestCase
  # Tests using a "by user" query of the "Show Locations" link on the obs index
  def test_advanced_search_with_name_and_location
    rolf.update(layout_count: 100)
    login

    visit(search_advanced_path)
    assert_match(:app_advanced_search.l, page.title, "Wrong page")
    assert_field("search_search_name")
    assert_field("search_search_where")
    fill_in("search_search_name", with: names(:fungi).text_name)
    fill_in("search_search_where",
            with: locations(:falmouth).display_name)
    assert_checked_field("content_filter_has_images_")
    assert_checked_field("content_filter_has_specimen_")
    within("#advanced_search_form") do
      click_commit
    end
    expected_hits = Observation.where(name: names(:fungi),
                                      location: locations(:falmouth).id)
    total_hits = all(".matrix-box", visible: :any).count

    assert_equal(expected_hits.count, total_hits)
    assert_match(:OBSERVATIONS.l, page.title, "Wrong page")
    page.find("#filters").assert_text(:query_has_images.l)
    page.find("#filters").assert_text(:query_has_specimen.l)
  end
end

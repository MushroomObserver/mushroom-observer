# frozen_string_literal: true

require("test_helper")

class AdvancedSearchIntegrationTest < CapybaraIntegrationTestCase
  # Tests using a "by user" query of the "Show Locations" link on the obs index
  def test_advanced_search_with_name_and_location
    rolf.update(layout_count: 100)
    login

    visit(search_advanced_path)
    assert_match(:app_advanced_search.l, page.title, "Wrong page")
    assert_field("search_name")
    assert_field("search_user_where")
    fill_in("search_name", with: names(:fungi).text_name)
    fill_in("search_user_where",
            with: locations(:falmouth).display_name)
    assert_checked_field("content_filter_with_images_")
    assert_checked_field("content_filter_with_specimen_")
    within("#advanced_search_form") do
      click_commit
    end
    assert_match(:app_advanced_search.l, page.title, "Wrong page")
    obs = Observation.where(name: names(:fungi),
                            location: locations(:falmouth).id)
    total = all(".matrix-box", visible: :any).count
    assert_equal(obs.count, total)
  end
end
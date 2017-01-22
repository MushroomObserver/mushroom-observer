require "test_helper"
require "capybara_helper"

# Test observer_controller/user_controller
class ObserverUserControllerTest < IntegrationTestCase
  # Following test fails, exposing a bug in the app.
  # I don't know how to fix the bug.
  def test_next_and_prev
    pattern = "name_sorts_user"
    expected_hits = User.where("login LIKE ?", "%#{pattern}").order(:name)

    visit("/")
    fill_in("search_pattern", with: pattern)
    page.select("User", from: :search_type)
    click_button("Search")

    # Results should have correct # of users
    # (Fixtures should be defined so that there are only 2 matches.)
    results = page.find(".results")
    results.assert_selector("a", count: 2)

    # First result should be User whose name is first in alpha order.
    assert_match(/#{expected_hits.first.name}/, results.first("a").text)

    # Different sort order should change the order of the results
    # (because of the definitions of Fixtures which match this search).
    click_on("Login Name")
    results = page.find(".results")
    assert_match(/#{expected_hits.second.name}/, results.first("a").text)

    results.first("a").click
    assert_match(%r{Contribution Summary for #{expected_hits.second.name}},
                    page.title, "Wrong page")

    # Prove that next_user and prev_user redirect to correct page
    click_on("Next")
    assert_match(%r{Contribution Summary for #{expected_hits.first.name}},
                    page.title, "Wrong page")

    click_on("Previous")
    assert_match(%r{Contribution Summary for #{expected_hits.second.name}},
                    page.title, "Wrong page")
  end
end

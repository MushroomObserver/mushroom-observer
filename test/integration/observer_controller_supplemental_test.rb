require "test_helper"

# Tests which supplement controller/observer_controller_test.rb
class ObserverControllerSupplementalTest < IntegrationTestCase
  # When someone enters text in the Textile Sandbox and clicks the Test button,
  #  MO should show what the entered text looks like.
  def test_post_textile
    visit("/observer/textile_sandbox")
    fill_in("code", with: "Jabberwocky")
    click_button("Test")
    page.assert_text("Jabberwocky", count: 2)
  end

  # Covers ObservationController#map_observations.
  def test_map_observations
    name = names(:boletus_edulis)
    visit("/name/map/#{name.id}")
    click_link("Show Observations")
    click_link("Show Map")
    title = page.find_by_id("title")

    title.assert_text("Observations of #{name.text_name}")
  end

  # If users clicks on Observation in Observation search results and destroys
  # Observation, MO should redirect to next Observation in results.
  def test_destroy_observation_from_search
    # Test needs a user with multiple observations with predictable sorts.
    user = users(:sortable_obs_user)

    visit("/account/login")
    fill_in("User name or Email address:", with: user.login)
    fill_in("Password:", with: "testpassword")
    click_button("Login")

    click_link("Your Observations", match: :first)
    # Predict 1st and 2nd Observations on this page.
    sort_order = QueryRecord.last.query.default_order
    observations = Observation.where(user: user).order(sort_order => :desc)
    first_obs = observations.first
    next_obs = observations.second

    # Show first Observation from Your Observations search.
    click_link(first_obs.id.to_s)
    # Destroy it.
    within("div#right_tabs") { click_link("Destroy") }

    # MO should show next Observation.
    title = page.find_by_id("title")
    assert_match(%r{#{:app_title.l}: Observation #{next_obs.id}}, page.title,
                 "Wrong page")
  end
end

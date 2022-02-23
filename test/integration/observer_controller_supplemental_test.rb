# frozen_string_literal: true

require("test_helper")

# Tests which supplement controller/observer_controller_test.rb
class ObserverControllerSupplementalTest < IntegrationTestCase
  # Prove that when a user "Tests" the text entered in the Textile Sandbox,
  # MO displays what the entered text looks like.
  def test_post_textile
    login
    visit("/observer/textile_sandbox")
    fill_in("code", with: "Jabberwocky")
    click_button("Test")
    page.assert_text("Jabberwocky", count: 2)
  end

  # Covers ObservationController#map_observations.
  def test_map_observations
    login
    name = names(:boletus_edulis)
    visit("/name/map/#{name.id}")
    click_link("Show Observations")
    click_link("Show Map")
    title = page.find_by_id("title")
    title.assert_text("Map of Observation Index")
  end

  # Prove that if a user clicks an Observation in Observation search results
  # having multiple Observations, and then destroys the Observation,
  # MO redirects to the next Observation in results.
  def test_destroy_observation_from_search
    # Test needs a user with multiple observations with predictable sorts.
    user = users(:sortable_obs_user)

    login(user)
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
    page.find_by_id("title")
    assert_match(/#{:app_title.l}: Observation #{next_obs.id}/, page.title,
                 "Wrong page")
  end

  # Prove that unchecking a Project as part of editing an Observation
  # removes the Observation from the Project.
  def test_observation_edit_uncheck_project
    user = users(:dick)
    # user owns this Observation,
    observation = observations(:collected_at_obs)
    # which is part of this Project.
    project = projects(:obs_collected_and_displayed_project)

    # Log in user
    login(user)

    # Edit the Observation, unchecking the Project.
    visit("/observer/edit_observation/#{observation.id}")
    uncheck("project_id_#{project.id}")
    click_on("Save Edits", match: :first)

    assert_not_includes(project.observations, observation)
  end

  # Prove that unchecking a Species List as part of an Observation editing
  # removes the Observation from the Species List.
  def test_observation_edit_uncheck_species_list
    user = users(:mary)
    # user owns this Observation,
    observation = observations(:minimal_unknown_obs)
    # which is part of this Species List.
    species_list = species_lists(:unknown_species_list)

    login(user)

    # Edit the Observation, unchecking the Project.
    visit("/observer/edit_observation/#{observation.id}")
    uncheck("list_id_#{species_list.id}")
    click_on("Save Edits", match: :first)

    assert_not_includes(species_list.observations, observation)
  end

  def login(user = users(:zero_user))
    visit("/account/login")
    fill_in("User name or Email address:", with: user.login)
    fill_in("Password:", with: "testpassword")
    click_button("Login")
  end
end

# frozen_string_literal: true

require("test_helper")

# Tests which supplement controller/observations_controller_test.rb
class ObservationsIntegrationTest < CapybaraIntegrationTestCase
  # Prove that when a user "Tests" the text entered in the Textile Sandbox,
  # MO displays what the entered text looks like.
  def test_post_textile
    login
    visit("/info/textile_sandbox")
    fill_in("textile_sandbox_code", with: "Jabberwocky")
    click_button("Test")
    page.assert_text("Jabberwocky", count: 2)
  end

  # Covers ObservationController#map_observations.
  def test_map_observations
    login
    name = names(:boletus_edulis)
    visit("/names/#{name.id}/map")
    click_on("Show Observations", match: :first)
    assert_match("Observations", page.title)
    filters = page.find_by_id("filters")
    filters.assert_text(name.text_name)

    click_on("Show Map", match: :first)
    assert_match("Map of Observations", page.title)
    filters = page.find_by_id("filters")
    filters.assert_text(name.text_name)
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
    # (Why jump through all of these hoops instead of hard-coding order?)
    # sort_order = QueryRecord.last.query.default_order
    observations = Observation.where(user: user).order(log_updated_at: :desc)
    first_obs = observations.first
    next_obs = observations.second

    # Show first Observation from Your Observations search.
    click_link(first_obs.text_name)
    # Destroy it.
    click_button(class: "destroy_observation_link_#{first_obs.id}")

    # MO should show next Observation.
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
    visit(edit_observation_path(id: observation.id).to_s)
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

    # Edit the Observation, unchecking the Species List.
    visit(edit_observation_path(id: observation.id).to_s)
    uncheck("list_id_#{species_list.id}")
    click_on("Save Edits", match: :first)

    assert_not_includes(species_list.observations, observation)
  end

  def test_observation_label_download_not_logged_in
    visit(observations_downloads_path)
    assert_equal(403, page.status_code) # forbidden
  end

  def test_old_observation_path_not_logged_in
    visit(observation_path(Observation.first.id))
    assert_equal(403, page.status_code) # forbidden
  end

  def test_raw_id_path_not_logged_in
    visit("/#{Observation.first.id}")
    assert_equal(403, page.status_code) # forbidden
  end

  def test_locales_when_sending_email_question
    sender = users(:rolf)
    receiver = users(:mary)
    sender.update(locale: "fr")
    assert_equal("fr", sender.locale)
    assert_equal("en", receiver.locale)

    # I have no clue how to ensure translations are set any particular way.
    # This stub causes every single translation to be simply:
    #   "locale:mo.tag"
    # Makes it very easy to test which language is being used!
    # But note that the standard login helper won't work because it is
    # expecting the English translations to work correctly.
    translator = lambda do |*args|
      "#{I18n.locale}:#{args.first}"
    end

    I18n.stub(:t, translator) do
      Capybara.reset_sessions!
      visit("/account/login/new")
      fill_in("en:mo.login_user:", with: sender.login)
      fill_in("en:mo.login_password:", with: "testpassword")
      click_button("en:mo.login_login")
      visit("/users/#{receiver.id}/emails/new")
      fill_in("fr:mo.ask_user_question_subject", with: "Bonjour!")
      fill_in("fr:mo.ask_user_question_message:", with: "Ça va?")
      click_button("fr:mo.SEND")
      notices = page.find("#flash_notices")
      notices.assert_text("fr:mo.runtime_ask_user_question_success")
    end
  end

  def test_observation_pattern_search_with_bad_keyword
    correctable_pattern = "foo:campestrus"

    login
    visit("/")
    fill_in("pattern_search_pattern", with: correctable_pattern)
    page.select("Observations", from: :pattern_search_type)
    within("#pattern_search_form") { click_button("Search") }
    assert_match("Observations", page.title)
    assert_selector(
      "#flash_notices",
      text: :pattern_search_bad_term_error.tp(
        type: :observation, help: "", term: "\"foo\""
      ).as_displayed
    )
  end

  def test_observation_pattern_search_with_correctable_pattern
    correctable_pattern = "agaricis campestrus"

    login
    visit("/")
    fill_in("pattern_search_pattern", with: correctable_pattern)
    page.select("Observations", from: :pattern_search_type)
    within("#pattern_search_form") { click_button("Search") }

    assert_selector("#flash_notices",
                    text: :runtime_no_matches.l(type: :observations.l))
    assert_match("Observations", page.title)
    assert_selector("#results", text: "")

    corrected_pattern = "Agaricus campestris"
    assert_selector(
      "#content a[href *= 'observations?pattern=Agaricus+campestris']",
      text: names(:agaricus_campestris).search_name
    )
    assert_selector("#content div.alert-warning", text: corrected_pattern)
    obs = observations(:agaricus_campestris_obs)

    fill_in("pattern_search_pattern", with: corrected_pattern)
    page.select("Observations", from: :pattern_search_type)
    within("#pattern_search_form") { click_button("Search") }

    assert_no_selector("#content div.alert-warning")
    assert_selector("#title", text: "#{obs.id} #{obs.name.search_name}")
  end

  # Tests of show_name_helper module
  # Prove that all these links appear under "Observations of"
  def test_links_to_observations_of
    login
    # on ShowObservation page
    visit("/names/#{names(:chlorophyllum_rachodes).id}")
    assert_text(:obss_of_this_name.l)
    assert_text(:taxon_obss_other_names.l)
    assert_text(:obss_of_taxon.l)
    assert_text(:obss_taxon_proposed.l)
    assert_text(:obss_name_proposed.l)
  end

  def test_observation_project_checkbox_state_persistence
    proj = projects(:current_closed_project)
    user = users(:katrina)
    # Ensure fixtures not broken
    assert(proj.member?(user),
           "Need fixtures such that `user` is a member of `proj`")
    proj_checkbox = "project_id_#{proj.id}"
    login(user)

    # create an Observation with Project selected
    visit(new_observation_path)
    assert_selector("#observation_place_name", visible: :any)
    fill_in(id: "observation_place_name", visible: :any,
            with: locations(:unknown_location).name)
    check(proj_checkbox)
    first(:button, "Create").click

    # Prove that Project is re-checked for the next Observation
    visit(new_observation_path)
    assert(
      has_checked_field?(proj_checkbox),
      "current Project checkbox state should persist from recent Observation"
    )

    # Make project non-current
    proj.end_date = Time.zone.yesterday
    proj.save

    # Prove that Project is not re-checked for the next Observation
    visit(new_observation_path)
    assert(
      has_unchecked_field?(proj_checkbox),
      "non-current Project should never be auto-rechecked"
    )
  end

  # Test user's options when an out-of-date-range project is checked
  # when creating an Observation
  # proj.location == albion, proj.start_date 2010/9/26, end_date 2010/10/26
  def test_add_out_of_range_observation_to_project
    proj = projects(:past_project)
    user = users(:roy)
    # Ensure fixtures not broken
    assert(proj.member?(user),
           "Need fixtures such that `user` is a member of `proj`")
    proj_checkbox = "project_id_#{proj.id}"
    last_obs = Observation.recent_by_user(user).last
    last_location = last_obs.location # nybg_location
    obs_location = locations(:burbank)
    assert_not_equal(proj.location, last_location)
    assert_not_equal(proj.location, obs_location)
    login(user)

    # Try adding out-of-range Observation (by both date and location) to Project
    # It should reload the form with warnings and a hidden field
    visit(new_observation_path)
    assert_selector("#observation_place_name", visible: :any)
    assert(has_unchecked_field?(proj_checkbox),
           "Missing an unchecked box for Project which has ended")
    assert_field("observation_location_id",
                 type: :hidden, with: last_location.id)
    assert_field("observation_place_name", with: last_location.display_name)
    assert_field("observation_when_1i", with: Time.zone.today.year)
    assert_field("observation_when_2i", with: Time.zone.today.month)
    assert_field("observation_when_3i", with: Time.zone.today.day)
    check(proj_checkbox)
    assert_selector("##{proj_checkbox}[checked='checked']")
    assert_no_difference("Observation.count",
                         "Out-of-range Observation should not be created") do
      first(:button, "Create").click
    end

    assert_selector(
      "#flash_notices",
      text: :form_observations_there_is_a_problem_with_projects.t.strip_html
    )

    within("#project_messages") do # out-of-range warning message
      assert(has_text?(:form_observations_projects_out_of_range.l(
                         date: Time.zone.today.web_date,
                         place_name: last_location.display_name
                       )),
             "Missing out-of-range warning with observation date")
      assert(has_text?(proj.title) && has_text?(proj.constraints),
             "Warning is missing out-of-range project's title or constraints")
    end
    # assert_selector("#ignore_project_dates", visible: :hidden)
    assert_selector("##{proj_checkbox}[checked='checked']")

    # Test the different ways to overcome the warning
    # 1. Prove that Obs is created if user unchecks out-of-range Project
    uncheck(proj_checkbox)
    assert(has_unchecked_field?(proj_checkbox))
    assert_difference(
      "Observation.count", 1,
      "Out-of-range Obs should be created if user unchecks Project"
    ) do
      first(:button, "Create").click
    end
    assert(
      proj.observations.exclude?(Observation.last),
      "Observation should not be added to Project if user unchecks Project"
    )

    # 2. Prove that Observation is created if user fixes dates and
    # location to be in-range
    # First, change the location to be in range, but not the date.
    visit(new_observation_path)
    assert_selector("#observation_place_name", visible: :any)
    fill_in(id: "observation_place_name", visible: :any,
            with: proj.location.display_name)
    # this is what counts, would be handled by js
    find_field(id: "observation_location_id",
               type: :hidden).set(proj.location.id)
    check(proj_checkbox)
    first(:button, "Create").click
    assert_selector(
      "#flash_notices",
      text: :form_observations_there_is_a_problem_with_projects.t.strip_html
    )
    # Change the Obs date to be in range - this should do it.
    select(proj.end_date.day, from: "observation_when_3i")
    select(Date::MONTHNAMES[proj.end_date.month], from: "observation_when_2i")
    fill_in("observation_when_1i", with: proj.end_date.year)
    # must be re-set, why? Seems @location should be set by previous commit
    find_field(id: "observation_location_id",
               type: :hidden).set(proj.location.id)
    assert_difference(
      "Observation.count", 1,
      "Failed to created Obs after setting When within Project date range"
    ) do
      first(:button, "Create").click
    end
    assert(
      proj.observations.include?(Observation.last),
      "Failed to include Obs in Project when user fixes Observation When"
    )

    # 3. Prove Obs is created if user overrides Project date ranges
    visit(new_observation_path)
    assert_selector("#observation_place_name", visible: :any)
    fill_in(id: "observation_place_name", visible: :any,
            with: obs_location.name) # ignored, it's the ID that matters
    find_field(id: "observation_location_id", type: :hidden).
      set(obs_location.id) # this is what counts
    check(proj_checkbox)
    # reset Observation date, making it out-of-range
    select(Time.zone.today.day, from: "observation_when_3i")
    select(Date::MONTHNAMES[Time.zone.today.month],
           from: "observation_when_2i")
    fill_in("observation_when_1i", with: Time.zone.today.year)

    first(:button, "Create").click
    assert_selector(
      "#flash_notices",
      text: :form_observations_there_is_a_problem_with_projects.t.strip_html
    )
    check(:form_observations_projects_ignore_project_constraints.l)

    assert_difference(
      "Observation.count", 1,
      "Failed to create Obs after ignoring Project date range"
    ) do
      first(:button, "Create").click # override warning by clicking button
    end
    assert(
      proj.observations.include?(Observation.last),
      "Failed to include Obs in Project when user overrides warning"
    )
  end
end

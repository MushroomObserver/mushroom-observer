# frozen_string_literal: true

require("test_helper")

# Test relating to projects
class ProjectsIntegrationTest < CapybaraIntegrationTestCase
  def test_add_project_dates
    login(mary)
    title = "Super Grandiloquent National Fungal Foray"

    # Add project, default dates
    visit(projects_path)
    click_on(:list_projects_add_project.l)
    fill_in(:form_projects_title.l, with: title)
    click_on("Create")

    project = Project.order(created_at: :asc).last
    assert_equal(title, project.title)
    assert_equal(Time.zone.today, project.start_date,
                 "Project Start Date should default to current date")
    assert_equal(Time.zone.today, project.start_date,
                 "Project Start Date should default to current date")
  end

  def test_add_out_of_range_observation_to_project
    proj = projects(:past_project)
    user = users(:katrina)
    # Ensure fixtures not broken
    assert(proj.is_member?(user),
           "Need fixtures such that `user` is a member of `proj`")
    proj_checkbox = "project_id_#{proj.id}"
    login(user)

    # Try adding out-of-range Observation to Project
    # It should reload the form with warnings and a hidden field
    visit(new_observation_path)
    assert(has_unchecked_field?(proj_checkbox),
           "Missing an unchecked box for Project which has ended")
    fill_in(:WHERE.l, with: locations(:burbank).name)
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
      assert(has_text?(:form_observations_projects_out_of_range.t(
                         date: Time.zone.today
                       )),
             "Missing out-of-range warning with observation date")

      assert(has_text?(proj.title) &&
               has_text?("#{proj.start_date_str} - #{proj.end_date_str}"),
             "Warning is missing out-of-range project's title or date range")
    end
    assert_selector("#ignore_project_dates", visible: :hidden)
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
      proj.observations.exclude?(Observation.order(created_at: :asc).last),
      "Observation should not be added to Project if user unchecks Project"
    )

    # 2. Prove that Observation is created if user fixes dates to be in-range
    visit(new_observation_path)
    fill_in(:WHERE.l, with: locations(:burbank).name)
    check(proj_checkbox)
    first(:button, "Create").click
    assert_selector(
      "#flash_notices",
      text: :form_observations_there_is_a_problem_with_projects.t.strip_html
    )
    # Change the Obs date to be in range
    select(proj.end_date.day, from: "observation_when_3i")
    select(Date::MONTHNAMES[proj.end_date.month], from: "observation_when_2i")
    select(proj.end_date.year, from: "observation_when_1i")
    assert_difference(
      "Observation.count", 1,
      "Failed to created Obs after setting When within Project date range"
    ) do
      first(:button, "Create").click
    end
    assert(
      proj.observations.include?(Observation.order(created_at: :asc).last),
      "Failed to include Obs in Project when user fixes Observation When"
    )

    # 3. Prove Obs is created if user overrides Project date ranges
    visit(new_observation_path)
    fill_in(:WHERE.l, with: locations(:burbank).name)
    check(proj_checkbox)
    # reset Observation date, making it out-of-range
    select(Time.zone.today.day, from: "observation_when_3i")
    select(Date::MONTHNAMES[Time.zone.today.month],
           from: "observation_when_2i")
    select(Time.zone.today.year, from: "observation_when_1i")
    first(:button, "Create").click
    assert_selector(
      "#flash_notices",
      text: :form_observations_there_is_a_problem_with_projects.t.strip_html
    )
    assert_difference(
      "Observation.count", 1,
      "Failed to create Obs after ignoring Project date range"
    ) do
      first(:button, "Create").click # override warning by clicking button
    end
    assert(
      proj.observations.include?(Observation.order(created_at: :asc).last),
      "Failed to include Obs in Project when user overrides warning"
    )
  end

  def test_project_checkbox_state_persistence
    proj = projects(:current_closed_project)
    user = users(:katrina)
    # Ensure fixtures not broken
    assert(proj.is_member?(user),
           "Need fixtures such that `user` is a member of `proj`")
    proj_checkbox = "project_id_#{proj.id}"
    login(user)

    # create an Observation with Project selected
    visit(new_observation_path)
    fill_in(:WHERE.l, with: locations(:burbank).name)
    check(proj_checkbox)
    first(:button, "Create").click

    # Test that Project is re-checked for the next Observation
    visit(new_observation_path)
    assert(
      has_checked_field?(proj_checkbox),
      "current Project checkbox state should persist from recent Observation"
    )

    # Make project non-current
    proj.end_date = Time.zone.yesterday
    proj.save

    # Test that Project is not re-checked for the next Observation
    login(:katrina)
    visit(new_observation_path)
    assert(
      has_unchecked_field?(proj_checkbox),
      "non-current Project should never be auto-rechecked"
    )
  end
end

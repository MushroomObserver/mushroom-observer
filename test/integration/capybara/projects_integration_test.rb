# frozen_string_literal: true

require("test_helper")

# Test relating to projects
class ProjectsIntegrationTest < CapybaraIntegrationTestCase
  def test_add_project
    login(mary)
    title = "Super Grandiloquent National Fungal Foray"

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

  def test_add_observation_to_out_of_range_project
    proj = projects(:past_project)
    user = users(:katrina)
    assert(proj.is_member?(user), # Ensure fixtures not broken
           "Need fixtures such that `user` is a member of `proj`")
    proj_checkbox = "project_id_#{proj.id}"
    observation_original_count = Observation.count

    login(user)
    visit(new_observation_path)
    assert(has_unchecked_field?(proj_checkbox),
           "Missing an unchecked box for Project which has ended")

    fill_in(:WHERE.l, with: locations(:burbank).name)
    check(proj_checkbox)
    first(:button, "Create").click

    # Prove MO shows appropriate messages when user checks out-of-range Project
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

    # Prove that Observation is created if user unchecks out-of-range Project
    uncheck(proj_checkbox)
    assert(has_unchecked_field?(proj_checkbox))
    first(:button, "Create").click
    assert_equal(
      observation_original_count + 1, Observation.count,
      "Failed to create Obs after unchecking out-if-range Projectx"
    )

    # Prove that Observation is created if user fixes dates to be in-range
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
    first(:button, "Create").click
    assert_equal(
      observation_original_count + 2, Observation.count,
      "Failed to created Obs after setting When within Project date range"
    )

    # Prove Observation is created if user overrides Project date ranges
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
    # Override Project date ranges
    check(:form_observations_projects_ignore_project_dates.l)
    first(:button, "Create").click
    assert_equal(
      observation_original_count + 3, Observation.count,
      "Failed to create Obs after overriding Project date ranges"
    )
  end
end

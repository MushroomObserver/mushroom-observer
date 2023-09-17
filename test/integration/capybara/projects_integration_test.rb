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
    assert_not(has_checked_field?(proj_checkbox),
               "Checkbox should be blank for Project which has ended")

    fill_in(:WHERE.l, with: locations(:burbank).name)
    check(proj_checkbox)
    first(:button, "Create").click

    # Prove MO shows appropriate messages when user checks out-of-range project
    assert_selector(
      "#flash_notices",
      text: :form_observations_there_is_a_problem_with_projects.t.strip_html
    )
    assert_selector(
      "#project_messages",
      text: :form_observations_projects_out_of_range.t(
        date: Time.zone.today # Observation.date
      ).strip_html
    )
    assert_selector("#project_messages", text: proj.title)
    assert_selector("#project_messages", text: proj.start_date)
    assert_selector("#project_messages", text: proj.end_date)

    # Prove that Observation iis created if user unchecks out-of-range project
    uncheck(proj_checkbox)
    assert_not(has_checked_field?(proj_checkbox))
    first(:button, "Create").click
    assert_equal(
      observation_original_count + 1, Observation.count,
      "Unchecking past Project checkbox should allow Observation creation"
    )

    # Again try to create Obs with out-of-range Project checked
    visit(new_observation_path)
    fill_in(:WHERE.l, with: locations(:burbank).name)
    check(proj_checkbox)
    first(:button, "Create").click
    # Change the Obs date to be in range
    select(proj.end_date.day, from: "observation_when_3i")
    select(Date::MONTHNAMES[proj.end_date.month], from: "observation_when_2i")
    select(proj.end_date.year, from: "observation_when_1i")
    first(:button, "Create").click
    assert_equal(
      observation_original_count + 2, Observation.count,
      "Unchecking past Project checkbox should allow Observation creation"
    )
  end
end

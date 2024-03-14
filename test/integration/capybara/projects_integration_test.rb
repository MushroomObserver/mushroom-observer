# frozen_string_literal: true

require("test_helper")

# Test relating to projects
class ProjectsIntegrationTest < CapybaraIntegrationTestCase
  def test_add_project_dates
    login(mary)
    title = "Ongoing Project Any Dates"

    # ----- Add project, default dates
    visit(projects_path)
    click_on(:list_projects_add_project.l)
    fill_in("project_title", with: title)
    fill_in(:WHERE.l, with: locations(:unknown_location).name)
    assert_selector(
      "input[type='radio'][id='project_dates_any_true'][checked='checked']"
    )
    assert_selector("input[type='radio'][id='project_dates_any_false']")

    assert_difference("Project.count", 1, "Failed to created Project") do
      click_on("Create")
    end

    project = Project.find_by_title(title)

    assert_nil(project.start_date, "Project Start Date should be nil")
    assert_nil(project.end_date, "Project Start Date should be nil")

    # ----- Add project, specified date range
    title = "Super International Fungal Foray"
    visit(projects_path)
    click_on(:list_projects_add_project.l)
    fill_in("project_title", with: title)
    fill_in(:WHERE.l, with: locations(:unknown_location).name)
    choose("project_dates_any_false")
    assert_selector(
      "input[type='radio'][id='project_dates_any_false'][checked='checked']"
    )

    default_start_and_end_date = Time.zone.today

    assert_difference("Project.count", 1, "Failed to created Project") do
      click_on("Create")
    end

    project = Project.find_by_title(title)
    assert_equal(title, project.title)
    assert_equal(project.start_date, default_start_and_end_date,
                 "Project Start Date should be today")
    assert_equal(project.end_date, default_start_and_end_date,
                 "Project End Date should be today")
  end

  def test_project_change_to_any_dates
    project = projects(:pinned_date_range_project)
    login(project.user.login)

    visit(project_path(project))
    click_on(:show_project_edit.l)
    choose("project_dates_any_true")
    assert_selector(
      "input[type='radio'][id='project_dates_any_true'][checked='checked']"
    )
    click_on(:SAVE_EDITS.l)

    project = Project.find_by_title(project.title)
    assert_nil(project.start_date, "Project Start Date should be nil")
    assert_nil(project.end_date, "Project Start Date should be nil")
  end

  def test_project_violations
    project = projects(:falmouth_2023_09_project)

    login(project.user.login)
    visit(project_path(project))

    click_on(:CONSTRAINT_VIOLATIONS.l)
  end
end

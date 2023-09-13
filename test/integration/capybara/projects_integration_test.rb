# frozen_string_literal: true

require("test_helper")

# Test adding, editing, and deleting a Sequence
class ProjectsIntegrationTest < CapybaraIntegrationTestCase
  def test_sequence
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
end

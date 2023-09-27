# frozen_string_literal: true

require("test_helper")

class ProjectsControllerTest < FunctionalTestCase
  ##### Helpers (which also assert) ############################################
  def add_project_helper(title, summary)
    params = {
      project: {
        title: title,
        summary: summary
      }
    }
    post_requires_login(:create, params)
    assert_form_action(action: :create, id: nil) # Failure
  end

  def edit_project_helper(title, project)
    params = {
      id: project.id,
      project: {
        title: title,
        summary: project.summary
      }
    }
    put_requires_user(:update, { action: :show }, params)
    assert_form_action(action: :update, id: project.id) # Failure
  end

  def destroy_project_helper(project, changer)
    assert(project)
    drafts = NameDescription.where(source_name: project.title)
    assert_not(drafts.empty?)
    params = { id: project.id.to_s }
    requires_user(:destroy, { action: :show }, params, changer.login)
    assert_redirected_to(project_path(project.id))
    assert(Project.find(project.id))
    assert(UserGroup.find(project.user_group.id))
    assert(UserGroup.find(project.admin_group.id))
    assert_obj_arrays_equal(drafts,
                            NameDescription.where(source_name: project.title))
  end

  ##############################################################################

  def test_show_project
    login("zero") # NOt the owner of eol_project
    p_id = projects(:eol_project).id
    get(:show, params: { id: p_id })
    assert_template("show")
    assert_select(
      "a[href*=?]", new_project_admin_request_path(project_id: p_id)
    )
    assert_select("a[href*=?]", edit_project_path(p_id), count: 0)
    assert_select(
      "a[href*=?]", new_project_member_path(project_id: p_id), count: 0
    )
    assert_select("form[action=?]", project_path(p_id), count: 0)
  end

  def test_show_project_logged_in
    p_id = projects(:eol_project).id
    requires_login(:new)
    get(:show, params: { id: p_id })
    assert_template("show")
    assert_select("a[href*=?]",
                  new_project_admin_request_path(project_id: p_id))
    assert_select("a[href*=?]", edit_project_path(p_id))
    assert_select("a[href*=?]", new_project_member_path(project_id: p_id))
    assert_select("form[action=?]", project_path(p_id))
  end

  def test_index
    login
    get(:index)

    assert_displayed_title("Projects by Time Last Modified")
    assert_template("index")
  end

  def test_index_with_non_default_sort
    login

    get(:index, params: { by: "created_at" })

    assert_template("index")
    assert_displayed_title("Projects by Date Created")
  end

  def test_index_member
    login

    get(:index, params: { member: dick.id })

    assert_template("index")
    assert_displayed_title("Project Index")
  end

  def test_index_by_summary
    login

    get(:index, params: { by: "summary" })

    assert_template("index")
    assert_displayed_title("Projects by Summary")
  end

  def test_index_pattern_search_multiple_hits
    pattern = "Project"

    login
    get(:index, params: { pattern: "Project" })

    assert_displayed_title("Projects Matching ‘#{pattern}’")
  end

  def test_index_pattern_search_by_name_one_hit
    project = projects(:bolete_project)

    login
    get(:index, params: { pattern: "Bolete Project" })

    q = QueryRecord.last.id.alphabetize
    assert_redirected_to(project_path(project.id, q: q))
  end

  def test_index_pattern_search_by_id
    project = projects(:bolete_project)

    login
    get(:index, params: { pattern: project.id.to_s })

    assert_response(:success)
    assert_displayed_title("Project: #{project.title}")
  end

  def test_add_project
    requires_login(:new)
    assert_form_action(action: :create)
  end

  def test_create_project
    title = "Amanita Research"
    summary = "The Amanita Research Project"
    project = Project.find_by(title: title)
    assert_nil(project)
    user_group = UserGroup.find_by(name: title)
    assert_nil(user_group)
    admin_group = UserGroup.find_by(name: "#{title}.admin")
    assert_nil(admin_group)
    params = {
      project: {
        title: title,
        summary: summary
      }
    }
    post_requires_login(:create, params)
    project = Project.find_by(title: title)
    assert_redirected_to(project_path(project.id))
    assert(project)
    assert_equal(title, project.title)
    assert_equal(summary, project.summary)
    assert_equal(rolf, project.user)
    user_group = UserGroup.find_by(name: title)
    assert(user_group)
    assert_equal([rolf], user_group.users)
    admin_group = UserGroup.find_by(name: "#{title}.admin")
    assert(admin_group)
    assert_equal([rolf], admin_group.users)
  end

  def test_add_project_existing
    project = projects(:eol_project)
    add_project_helper(project.title,
                       "The Entoloma On Line Project")
  end

  def test_add_project_empty_name
    add_project_helper("", "The Empty Project")
  end

  def test_add_project_existing_user_group
    add_project_helper("reviewers", "Journal Reviewers")
  end

  def test_add_project_existing_admin_group
    add_project_helper("The Test Coverage Project", "")
  end

  def test_edit_project
    project = projects(:eol_project)
    params = { id: project.id.to_s }
    requires_user(:edit, { action: :show }, params)
    assert_form_action(action: :update, id: project.id.to_s)
  end

  def test_update_project
    title = "EOL Project"
    summary = "This has become the Entoloma On Line project"
    project = Project.find_by(title: title)
    assert(project)
    assert_not_equal(summary, project.summary)
    assert_not(project.open_membership)
    params = {
      id: project.id,
      project: {
        title: title,
        summary: summary,
        open_membership: true
      }
    }
    put_requires_user(:update, { action: :show }, params)
    project = Project.find_by(title: title)
    assert_redirected_to(project_path(project.id))
    assert(project)
    assert_equal(summary, project.summary)
    assert(project.open_membership)
  end

  def test_edit_project_empty_name
    edit_project_helper("", projects(:eol_project))
  end

  def test_edit_project_existing
    edit_project_helper(projects(:bolete_project).title,
                        projects(:eol_project))
  end

  def test_destroy_project
    project = projects(:bolete_project)
    assert(project)
    user_group = project.user_group
    assert(user_group)
    admin_group = project.admin_group
    assert(admin_group)
    drafts = NameDescription.where(source_name: project.title)
    project_draft_count = drafts.length
    assert(project_draft_count.positive?)
    params = { id: project.id.to_s }
    requires_user(:destroy, { action: :show }, params, "dick")
    assert_redirected_to(projects_path)
    assert_raises(ActiveRecord::RecordNotFound) do
      project = Project.find(project.id)
    end
    assert_raises(ActiveRecord::RecordNotFound) do
      user_group = UserGroup.find(user_group.id)
    end
    assert_raises(ActiveRecord::RecordNotFound) do
      admin_group = UserGroup.find(admin_group.id)
    end
    n = NameDescriptionAdmin.
        where(user_group: [admin_group.id, user_group.id]).count
    assert_equal(
      0, n,
      "Project admin/user group has been destroyed, " \
      "no name descriptions should refer to it to set admin privileges."
    )
    n = NameDescriptionWriter.
        where(user_group: [admin_group.id, user_group.id]).count
    assert_equal(
      0, n,
      "Project admin/user group has been destroyed, " \
      "no name descriptions should refer to it to set write permissions."
    )
    n = NameDescriptionReader.
        where(user_group: [admin_group.id, user_group.id]).count
    assert_equal(
      0, n,
      "Project admin/user group has been destroyed, " \
      "no name descriptions should refer to it to set read permissions."
    )
    drafts.each do |draft|
      assert_not_equal(
        :project, draft.reload.source_type,
        "Project destruction failed to reset NameDescription's source_type"
      )
    end
  end

  def test_destroy_project_other
    destroy_project_helper(projects(:bolete_project), rolf)
  end

  def test_destroy_project_member
    eol_project = projects(:eol_project)
    assert(eol_project.is_member?(katrina))
    destroy_project_helper(eol_project, katrina)
  end

  def test_changing_project_name
    proj = projects(:eol_project)
    login("rolf")
    put(:update,
        params: {
          id: projects(:eol_project).id,
          project: { title: "New Project", summary: "New Summary" }
        })
    assert_flash_success
    proj = proj.reload
    assert_equal("New Project", proj.title)
    assert_equal("New Summary", proj.summary)
  end
end

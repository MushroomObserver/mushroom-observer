# frozen_string_literal: true

require("test_helper")

class ProjectsControllerTest < FunctionalTestCase
  def build_params(
    title, summary, start_date: nil, end_date: nil,
    dates_any: "false"
  )
    {
      project: {
        title: title,
        summary: summary,
        place_name: "",
        open_membership: false,
        "start_date(1i)" => start_date&.year,
        "start_date(2i)" => start_date&.month,
        "start_date(3i)" => start_date&.day,
        "end_date(1i)" => end_date&.year,
        "end_date(2i)" => end_date&.month,
        "end_date(3i)" => end_date&.day,
        dates_any: dates_any
      },
      upload: {
        license_id: licenses(:ccnc25).id,
        copyright_holder: User.current&.name || "Someone Else",
        copyright_year: 2023
      }
    }
  end

  ##### Helpers (which also assert) ############################################
  def add_project_helper(title, summary)
    post_requires_login(:create, build_params(title, summary))
    assert_form_action(action: :create)
  end

  def edit_project_helper(title, project)
    params = build_params(title, project.summary)
    params[:id] = project.id
    put_requires_user(:update, { action: :show }, params)
    assert_form_action(action: :update, id: project.id)
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
    login("zero") # Not the owner of eol_project
    p_id = projects(:eol_project).id
    get(:show, params: { id: p_id })

    assert_template("show")
    assert_select(
      "a[href*=?]", new_project_admin_request_path(project_id: p_id)
    )
    assert_select("a[href*=?]", edit_project_path(p_id), false,
                  "Non-admin should not see link to edit project")
    assert_select(
      "a[href*=?]", new_project_member_path(project_id: p_id), count: 0
    )
    assert_select("form[action=?]", project_path(p_id), count: 0)
  end

  def test_show_project_logged_in_owner
    project = projects(:eol_project)

    login(project.user.login)
    get(:show, params: { id: project.id })

    assert_template("show")
    assert_select("a[href*=?]", edit_project_path(project), true,
                  "Project owner should see link to edit project")
  end

  def test_show_project_logged_in_admin
    project = projects(:eol_project)
    assert(project.admin?(mary))

    login(mary.login)
    get(:show, params: { id: project.id })

    assert_template("show")
    assert_select("a[href*=?]", edit_project_path(project), true,
                  "Project admmin should see link to edit project")
  end

  def test_show_project_with_location
    project = projects(:albion_project)
    login
    get(:show, params: { id: project.id })

    assert_select("a[href*=?]", location_path(project.location.id))
  end

  # exposes bug found ruing development
  def test_show_project_with_location_stradding_date_line
    project = projects(:wrangel_island_project)
    login

    get(:show, params: { id: project.id })

    assert_template("show")
  end

  def test_show_project_with_date_range
    project = projects(:pinned_date_range_project)
    login
    get(:show, params: { id: project.id })

    assert_select("#header", { text: /#{project.date_range}/ },
                  "Date range missing from Project header")
  end

  def test_show_project_with_constraint_violations
    project = projects(:falmouth_2023_09_project)
    violations_count = project.count_violations
    assert(violations_count.positive?,
           "Test needs Project fixture with constraint violations")
    user = project.user

    login(user.login)
    get(:show, params: { id: project.id })

    assert_select(
      "#project_summary a[href =
        '#{edit_project_violations_path(id: project.id)}']",
      true, "Page is missing a link to violations"
    )
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
    assert_displayed_title(project.title)
  end

  def test_add_project
    requires_login(:new)

    assert_form_action(action: :create)
    assert_select(
      'select[id ^= "project_start_date"]', { count: 3 },
      "Form should have fields to select starting month, day, year"
    )
    assert_select(
      'select[id ^= "project_end_date"]', { count: 3 },
      "Form should have fields to select ending month, day, year"
    )

    assert_select(
      "input[type=radio][id=project_dates_any_true]", { count: 1 },
      "Missing radio button to make project dates any dates"
    )
    assert_select(
      "input[type=radio][id=project_dates_any_false]", { count: 1 },
      "Missing radio button to make project dates a range"
    )

    assert_select(
      "input[type=radio][id=project_dates_any_true][checked=checked]",
      { count: 1 },
      "'Any' dates radio button should be checked by default"
    )
  end

  def test_create_project_with_date_range
    title = "Amanita Research"
    summary = "The Amanita Research Project"
    project = Project.find_by(title: title)
    assert_nil(project)
    user_group = UserGroup.find_by(name: title)
    assert_nil(user_group)
    admin_group = UserGroup.find_by(name: "#{title}.admin")
    assert_nil(admin_group)
    start_date = Date.tomorrow
    end_date = start_date + 3.days

    post_requires_login(
      :create, build_params(title, summary,
                            start_date: start_date, end_date: end_date)
    )

    project = Project.find_by(title: title)
    assert_redirected_to(project_path(project.id))
    assert(project)
    assert_equal(title, project.title)
    assert_equal(summary, project.summary)
    assert_equal(start_date, project.start_date)
    assert_equal(end_date, project.end_date)
    assert_equal(rolf, project.user)
    user_group = UserGroup.find_by(name: title)
    assert(user_group)
    assert_equal([rolf], user_group.users)
    admin_group = UserGroup.find_by(name: "#{title}.admin")
    assert(admin_group)
    assert_equal([rolf], admin_group.users)
  end

  def test_create_project_with_any_dates
    title = "Project without start or end"
    start = Time.zone.today

    post_requires_login(
      :create,
      build_params(
        title, "", start_date: start, end_date: start, dates_any: true
      )
    )

    project = Project.find_by(title: title)
    assert_redirected_to(project_path(project.id))
    assert_nil(project.start_date)
    assert_nil(project.end_date)
  end

  def test_create_project_end_before_start
    title = "Backward in Time"
    start_date = Time.zone.today
    params = build_params(
      title, "Ends before it starts",
      start_date: start_date, end_date: start_date - 1.day, dates_any: false
    )

    assert_no_difference("Project.count", "Project ends before start") do
      post_requires_login(:create, params)
    end

    assert_flash_error("Missing flash error when Project ends before it starts")
    assert_nil(
      Project.find_by(title: title),
      "It chould not create a Project which ends before ti starts"
    )

    assert_form_action(
      { action: :create, id: nil },
      "Failed to return to form when Project ended before it started"
    )
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

  def test_edit_project_by_owner
    project = projects(:two_list_project)
    # `requires_user` calls `either_requires_either` which calls
    # `assert_request` which requires that
    # the request pass with the supplied user, and
    # fail with an unsupplied user, who is either
    #   mary if the suppled user was rolf, or
    #   rolf if the supplied user was other than mary or rolf
    assert(project.user == mary && !project.admin?(rolf),
           "Test needs different fixtures")
    project_id = project.id.to_s
    params = { id: project_id }

    requires_user(:edit, { action: :show }, params, "mary")

    assert_form_action(action: :update, id: project.id.to_s)
  end

  def test_edit_project_any_date
    project = projects(:bolete_project)
    assert_true(project.start_date.nil? && project.end_date.nil?,
                "Test needs Project with nil start and end dates")
    params = { id: project.id.to_s }

    login(project.user.login)
    post(:edit, params: params)

    assert_select("#project_dates_any_true[checked]", true,
                  "'Any' radio button should be selected")
  end

  def test_edit_project_empty_name
    edit_project_helper("", projects(:rolf_project))
  end

  def test_edit_project_existing
    edit_project_helper(projects(:bolete_project).title,
                        projects(:rolf_project))
  end

  def test_update_project
    title = "EOL Project"
    summary = "This has become the Entoloma On Line project"
    project = Project.find_by(title: title)
    assert(project)
    assert_not_equal(summary, project.summary)
    assert_not(project.open_membership)
    start_date = Time.zone.today
    end_date = start_date + 4.days
    params =
      build_params(title, summary,
                   start_date: start_date, end_date: end_date)

    params[:project][:open_membership] = true
    params[:id] = project.id

    put_requires_user(:update, { action: :show }, params)

    project = Project.find_by(title: title)
    assert_redirected_to(project_path(project.id))
    assert(project)
    assert_equal(summary, project.summary)
    assert(project.open_membership)
    assert_equal(start_date, project.start_date)
    assert_equal(end_date, project.end_date)
  end

  def test_update_project_end_before_start
    proj = projects(:pinned_date_range_project)
    start_date = Time.zone.today
    params = build_params(
      proj.title, proj.summary,
      start_date: start_date, end_date: start_date - 1.day, dates_any: false
    ).merge(id: proj.id)

    login(proj.user.login)
    patch(:update, params: params)

    assert_flash_error("Missing flash error when Project ends before it starts")
    assert_select("#title", { text: /Edit Project/ },
                  "It should return to form if Project ends before it starts")
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

  # prove that mere member cannot destroy project
  def test_destroy_project_member
    project = projects(:rolf_project)
    member = users(:katrina)
    assert(
      project.member?(member) && project.user != member &&
      !project.admin?(member) &&
      NameDescription.where(source_name: project.title).any?,
      "Bad fixtures: member must be project member, but not owner or admin " \
      "and project must be the source of a NameDescription"
    )

    destroy_project_helper(project, katrina)
  end

  def test_changing_project_name
    proj = projects(:eol_project)
    login("rolf")
    params = build_params("New Project", "New Summary")
    params[:id] = projects(:eol_project).id

    put(:update, params: params)

    assert_flash_success
    proj = proj.reload
    assert_equal("New Project", proj.title)
    assert_equal("New Summary", proj.summary)
  end

  def test_user_group_save_fail
    title = "Bad User Group"
    user_group = user_groups(:bolete_users)
    user_group.stub(:save, false) do
      UserGroup.stub(:new, user_group) do
        post_requires_login(:create, build_params(title, title))
        assert_nil(Project.find_by(title: title))
      end
    end
  end

  def test_good_location
    where = locations(:albion).name
    title = "#{where} Project"
    params = build_params(title, title)
    params[:project][:place_name] = where
    post_requires_login(:create, params)
    project = Project.find_by(title: title)
    assert_equal(project.location.name, where)
  end

  def test_add_project_member
    title = "Great Project"
    params = build_params(title, title)
    post_requires_login(:create, params)
    project = Project.find_by(title: title)
    assert_equal(1, project.project_members.count)
  end

  def test_bad_location
    where = "This is a bad place"
    title = "#{where} Project"
    params = build_params(title, title)
    params[:project][:place_name] = where
    post_requires_login(:create, params)
    assert_nil(Project.find_by(title: title))
  end

  def test_project_save_fail
    title = "Bad Project"
    project = projects(:eol_project)
    project.stub(:save, false) do
      Project.stub(:new, project) do
        post_requires_login(:create, build_params(title, title))
        assert_nil(Project.find_by(title: title))
      end
    end
  end

  def test_project_destroy_fail
    project = projects(:eol_project)
    project.stub(:destroy, false) do
      Project.stub(:safe_find, project) do
        project_id = project.id
        params = { id: project_id.to_s }
        requires_user(:destroy, { action: :show }, params, "rolf")
        assert_flash_error
      end
    end
  end

  def image_setup
    setup_image_dirs
    Rack::Test::UploadedFile.new(
      Rails.root.join("test/images/sticky.jpg").to_s, "image/jpeg"
    )
  end

  def test_add_background_image
    file = image_setup
    num_images = Image.count
    params = build_params("With background", "With background")
    project = projects(:eol_project)
    params[:id] = project.id
    params[:project][:upload_image] = file
    File.stub(:rename, false) do
      login("rolf", "testpassword")
      put(:update, params: params)
    end
    assert_redirected_to(project_path(project.id))
    assert_flash_success

    project.reload
    assert_equal(num_images + 1, Image.count)
    assert_equal(Image.last.id, project.image_id)
    assert_equal(params[:upload][:copyright_holder],
                 project.image.copyright_holder)
    assert_equal(params[:upload][:copyright_year], project.image.when.year)
    assert_equal(params[:upload][:license_id], project.image.license_id)
  end

  def test_bad_background_image
    file = image_setup
    num_images = Image.count
    params = build_params("Bad background", "Bad background")
    project = projects(:eol_project)
    params[:id] = project.id
    params[:project][:upload_image] = file
    image = images(:peltigera_image)
    image.stub(:process_image, false) do
      File.stub(:rename, false) do
        login("rolf", "testpassword")
        Image.stub(:new, image) do
          put(:update, params: params)
        end
      end
    end

    project.reload
    assert_equal(num_images, Image.count)
  end

  def test_fail_save_background_image
    file = image_setup
    num_images = Image.count
    params = build_params("Bad background", "Bad background")
    project = projects(:eol_project)
    params[:id] = project.id
    params[:project][:upload_image] = file
    image = images(:peltigera_image)
    image.stub(:save, false) do
      File.stub(:rename, false) do
        login("rolf", "testpassword")
        Image.stub(:new, image) do
          put(:update, params: params)
        end
      end
    end

    project.reload
    assert_equal(num_images, Image.count)
  end

  def test_fail_update
    params = build_params("Bad update", "Bad update")
    params[:id] = 1
    login
    project = projects(:eol_project)
    project.stub(:update, false) do
      Project.stub(:find, project) do
        put(:update, params: params)
      end
    end
  end
end

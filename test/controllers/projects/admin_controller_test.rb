# frozen_string_literal: true

require("test_helper")

module Projects
  class AdminControllerTest < FunctionalTestCase
    setup do
      @controller = Projects::AdminController.new
      @project = projects(:eol_project)
      @admin = users(:rolf) # eol_project owner
      @non_admin = users(:katrina) # not in eol_admins
    end

    def test_show_renders_for_project_admin
      login(@admin.login)
      get(:show, params: { project_id: @project.id })

      assert_response(:success)
      # Details sub-tab embeds the project edit form
      assert_select("form[action=?]", project_path(@project.id),
                    true, "Edit form should be present")
      assert_select("input[name='project[title]'][value=?]",
                    @project.title, true,
                    "Title field should be pre-filled")
      # Sub-tabs link to Members and Aliases
      assert_select("a[href=?]",
                    project_members_path(@project.id),
                    true, "Members sub-tab should link to members page")
      assert_select("a[href=?]",
                    project_aliases_path(project_id: @project.id),
                    true, "Aliases sub-tab should link to aliases page")
      # Danger Zone with Delete Project
      assert_select("#project_danger_zone", true,
                    "Danger Zone section should be present")
    end

    def test_show_renders_admin_subtabs_with_details_active
      login(@admin.login)
      get(:show, params: { project_id: @project.id })

      assert_response(:success)
      assert_select("#project_admin_subtabs .nav-link.active",
                    { text: :show_project_admin_details_tab.l },
                    "Details sub-tab should be marked active")
    end

    def test_show_form_has_dirty_form_controller
      login(@admin.login)
      get(:show, params: { project_id: @project.id })

      assert_response(:success)
      assert_select("form[data-controller~='dirty-form']", true,
                    "Edit form should have the dirty-form Stimulus controller")
    end

    def test_show_redirects_non_admin
      login(@non_admin.login)
      get(:show, params: { project_id: @project.id })

      assert_redirected_to(project_path(@project.id))
      assert_flash_error
    end

    # Exercises the user_defaults branch of compute_image_ivars
    # for a project that has no banner image set.
    def test_show_renders_for_imageless_project
      project = projects(:empty_project)
      assert_nil(project.image, "Test needs a project with no image")
      login(project.user.login)
      get(:show, params: { project_id: project.id })

      assert_response(:success)
      assert_select("form[action=?]", project_path(project.id))
    end

    def test_show_requires_login
      get(:show, params: { project_id: @project.id })

      assert_redirected_to(new_account_login_path)
    end
  end
end

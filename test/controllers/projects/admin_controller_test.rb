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
      assert_select("a[href=?]",
                    edit_project_path(@project.id),
                    true,
                    "Edit Project link should be present")
      assert_select("a[href=?]",
                    project_members_path(@project.id),
                    true,
                    "Members link should be present")
      assert_select("a[href=?]",
                    project_aliases_path(project_id: @project.id),
                    true,
                    "Project Aliases link should be present")
    end

    def test_show_redirects_non_admin
      login(@non_admin.login)
      get(:show, params: { project_id: @project.id })

      assert_redirected_to(project_path(@project.id))
      assert_flash_error
    end

    def test_show_requires_login
      get(:show, params: { project_id: @project.id })

      assert_redirected_to(new_account_login_path)
    end
  end
end

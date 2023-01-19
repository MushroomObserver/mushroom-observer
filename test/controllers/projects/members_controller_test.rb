# frozen_string_literal: true

require("test_helper")

module Projects
  class MembersControllerTest < FunctionalTestCase
    ##### Helpers (which also assert) ##########################################
    def change_member_status_helper(changer, target_user, commit, admin_before,
                                    user_before, admin_after, user_after)
      eol_project = projects(:eol_project)
      assert_equal(admin_before,
                   target_user.in_group?(eol_project.admin_group.name))
      assert_equal(user_before,
                   target_user.in_group?(eol_project.user_group.name))
      params = {
        project_id: eol_project.id,
        candidate: target_user.id,
        commit: commit.l
      }

      put_requires_login(:update, params, changer.login)
      assert_redirected_to(project_path(eol_project.id))
      target_user = User.find(target_user.id)
      assert_equal(admin_after,
                   target_user.in_group?(eol_project.admin_group.name))
      assert_equal(user_after,
                   target_user.in_group?(eol_project.user_group.name))
    end

    # Huh? If it requires login, there ain't gonna be a form
    def test_change_member_status
      project = projects(:eol_project)
      params = {
        project_id: project.id,
        candidate: mary.id
      }
      requires_login(:edit, params)
      assert_form_action(action: :update,
                         candidate: mary.id, project_id: project.id)
    end

    # non-admin member -> non-admin member (should be a no-op)
    def test_change_member_status_member_make_member
      change_member_status_helper(rolf, katrina,
                                  :change_member_status_make_member,
                                  false, true, false, true)
    end

    # non-admin member -> admin member
    def test_change_member_status_member_make_admin
      change_member_status_helper(mary, katrina,
                                  :change_member_status_make_admin,
                                  false, true, true, true)
    end

    # non-admin member -> non-member
    def test_change_member_status_member_remove_member
      change_member_status_helper(rolf, katrina,
                                  :change_member_status_remove_member,
                                  false, true, false, false)
    end

    # admin member -> non-admin member
    def test_change_member_status_admin_make_member
      change_member_status_helper(mary, mary,
                                  :change_member_status_make_member,
                                  true, true, false, true)
    end

    # admin member -> admin member (should be a no-op)
    def test_change_member_status_admin_make_admin
      change_member_status_helper(rolf, mary,
                                  :change_member_status_make_admin,
                                  true, true, true, true)
    end

    # admin member -> non-member
    def test_change_member_status_admin_remove_member
      change_member_status_helper(mary, mary,
                                  :change_member_status_remove_member,
                                  true, true, false, false)
    end

    # non-member -> non-admin member
    def test_change_member_status_non_member_make_member
      change_member_status_helper(rolf, dick,
                                  :change_member_status_make_member,
                                  false, false, false, true)
    end

    # non-member -> admin member
    def test_change_member_status_non_member_make_admin
      change_member_status_helper(mary, dick,
                                  :change_member_status_make_admin,
                                  false, false, true, true)
    end

    # non-member -> non-member (should be a no-op)
    def test_change_member_status_non_member_remove_member
      change_member_status_helper(rolf, dick,
                                  :change_member_status_remove_member,
                                  false, false, false, false)
    end

    # The following should all be no-ops
    def test_change_member_status_by_member_make_member
      change_member_status_helper(katrina, dick,
                                  :change_member_status_make_member,
                                  false, false, false, false)
    end

    def test_change_member_status_by_non_member_make_admin
      change_member_status_helper(dick, katrina,
                                  :change_member_status_make_admin,
                                  false, true, false, true)
    end

    def test_change_member_status_by_member_remove_member
      change_member_status_helper(katrina, katrina,
                                  :change_member_status_remove_member,
                                  false, true, false, true)
    end

    # There are many other combinations that shouldn't work
    # for change_member_status, but I think the above covers the key cases

    # Make sure admin can see form.
    def test_add_members
      requires_login(:new, project_id: projects(:eol_project).id)
    end

    # Make sure non-admin cannot see form.
    def test_add_members_non_admin
      project_id = projects(:eol_project).id
      requires_login(:new, { project_id: project_id }, katrina.login)
      assert_redirected_to(project_path(project_id))
    end

    # Make sure admin can add members.
    def test_add_member_admin
      eol_project = projects(:eol_project)
      target_user = dick
      assert_equal(false, target_user.in_group?(eol_project.admin_group.name))
      assert_equal(false, target_user.in_group?(eol_project.user_group.name))
      params = {
        project_id: eol_project.id,
        candidate: target_user.id
      }
      post_requires_login(:create, params, mary.login)
      assert_redirected_to(project_path(eol_project.id))
      target_user = User.find(target_user.id)
      assert_equal(false, target_user.in_group?(eol_project.admin_group.name))
      assert_equal(true, target_user.in_group?(eol_project.user_group.name))
    end

    # Make sure mere member cannot add members.
    def test_add_member_member
      eol_project = projects(:eol_project)
      target_user = dick
      assert_equal(false, target_user.in_group?(eol_project.admin_group.name))
      assert_equal(false, target_user.in_group?(eol_project.user_group.name))
      params = {
        project_id: eol_project.id,
        candidate: target_user.id
      }
      post_requires_login(:create, params, katrina.login)
      assert_redirected_to(project_path(eol_project.id))
      target_user = User.find(target_user.id)
      assert_equal(false, target_user.in_group?(eol_project.admin_group.name))
      assert_equal(false, target_user.in_group?(eol_project.user_group.name))
    end

    def test_add_member_writein
      eol_project = projects(:eol_project)
      target_user = dick
      assert_not(target_user.in_group?(eol_project.admin_group.name))
      assert_not(target_user.in_group?(eol_project.user_group.name))
      params = {
        project_id: eol_project.id,
        candidate: "#{target_user.login} <Should Ignore This>"
      }
      post_requires_login(:create, params, mary.login)
      assert_redirected_to(project_path(eol_project.id))
      target_user.reload
      assert_not(target_user.in_group?(eol_project.admin_group.name))
      assert(target_user.in_group?(eol_project.user_group.name))
    end

    def test_add_member_bad_writein
      eol_project = projects(:eol_project)
      num_before = eol_project.user_group.users.count
      params = {
        project_id: eol_project.id,
        candidate: "freddymercury"
      }
      post_requires_login(:create, params, mary.login)
      assert_redirected_to(project_path(eol_project.id))
      assert_flash_error
      assert_equal(num_before, eol_project.reload.user_group.users.count)
    end
  end
end

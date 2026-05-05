# frozen_string_literal: true

require("test_helper")

module Projects
  class MembersControllerTest < FunctionalTestCase
    ##### Helpers (which also assert) ##########################################
    def change_member_status_helper(changer, target_user, commit, admin_before,
                                    user_before, admin_after, user_after)
      project = projects(:eol_project)
      assert_equal(admin_before,
                   target_user.in_group?(project.admin_group.name))
      assert_equal(user_before,
                   target_user.in_group?(project.user_group.name))
      check_project_membership(project, target_user, user_before)
      params = {
        project_id: project.id,
        candidate: target_user.id,
        commit: commit.l
      }

      put_requires_login(:update, params, changer.login)
      assert_redirected_to(project_members_path(project.id))
      target_user = User.find(target_user.id)
      assert_equal(admin_after,
                   target_user.in_group?(project.admin_group.name))
      assert_equal(user_after,
                   target_user.in_group?(project.user_group.name))
      check_project_membership(project, target_user, user_after)
    end

    def check_project_membership(project, user, member)
      membership = ProjectMember.find_by(project:, user:)
      if member
        assert_not_nil(membership)
      else
        assert_nil(membership)
      end
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

    def test_change_member_status_non_admin
      project = projects(:eol_project)
      params = {
        project_id: project.id,
        candidate: mary.id
      }
      requires_login(:edit, params, katrina.login)
      assert_flash_error
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
                                  false, true, false, false)
    end

    def test_change_member_status_by_member_make_admin
      change_member_status_helper(katrina, katrina,
                                  :change_member_status_make_admin,
                                  false, true, false, true)
    end

    # member sharing all observations
    def test_member_add_obs
      target_user = project_members(:eol_member_katrina).user
      project = projects(:eol_project)
      obs_count = project.observations.count
      params = {
        project_id: project.id,
        candidate: target_user.id,
        commit: :change_member_add_obs.l
      }
      put_requires_login(:update, params, target_user.login)
      assert_equal(obs_count + target_user.observations.count,
                   project.observations.count)
    end

    # issue #4129: already-added obs are not re-added by a second click
    def test_member_add_obs_dedup
      target_user = project_members(:eol_member_katrina).user
      project = projects(:eol_project)
      project.add_observations(target_user.observations)
      before_count = project.observations.count
      params = {
        project_id: project.id,
        candidate: target_user.id,
        commit: :change_member_add_obs.l
      }
      put_requires_login(:update, params, target_user.login)
      assert_equal(before_count, project.observations.count,
                   "Second add should be a no-op when all already in project")
    end

    # issue #4129: hard cap limits the number added per click
    def test_member_add_obs_caps_at_limit
      target_user = project_members(:eol_member_katrina).user
      project = projects(:eol_project)
      assert_operator(target_user.observations.count, :>=, 2,
                      "Test assumes target user has ≥2 obs not in project")
      before_count = project.observations.count
      params = {
        project_id: project.id,
        candidate: target_user.id,
        commit: :change_member_add_obs.l
      }
      Projects::MembersController.stub(:add_obs_batch_limit, 1) do
        put_requires_login(:update, params, target_user.login)
      end
      assert_equal(before_count + 1, project.observations.count,
                   "Cap should limit one click to add_obs_batch_limit obs")
    end

    # issue #4129: cap adds most-recent (highest id) first
    def test_member_add_obs_adds_most_recent_first
      target_user = project_members(:eol_member_katrina).user
      project = projects(:eol_project)
      expected_id = target_user.observations.order(id: :desc).first.id
      params = {
        project_id: project.id,
        candidate: target_user.id,
        commit: :change_member_add_obs.l
      }
      Projects::MembersController.stub(:add_obs_batch_limit, 1) do
        put_requires_login(:update, params, target_user.login)
      end
      assert_includes(project.observations.reload.map(&:id), expected_id,
                      "Cap should pick most-recent obs first")
    end

    # issue #4129: flash reports count actually added
    def test_member_add_obs_flash_count
      target_user = project_members(:eol_member_katrina).user
      project = projects(:eol_project)
      params = {
        project_id: project.id,
        candidate: target_user.id,
        commit: :change_member_add_obs.l
      }
      put_requires_login(:update, params, target_user.login)
      count = target_user.observations.count
      assert_flash_text(/Added #{count} Observations/)
    end

    # issue #4129: modal returns count of matching obs not in project
    def test_add_obs_modal_returns_turbo_stream_with_count
      target_user = project_members(:eol_member_katrina).user
      project = projects(:eol_project)
      login(target_user.login)
      get(:add_obs_modal,
          params: { project_id: project.id, candidate: target_user.id },
          format: :turbo_stream)
      assert_response(:success)
      assert_match(
        /#{target_user.observations.count}/, @response.body,
        "Modal body should include count of matching observations"
      )
    end

    # issue #4129: modal count excludes observations already in project
    def test_add_obs_modal_excludes_already_in_project
      target_user = project_members(:eol_member_katrina).user
      project = projects(:eol_project)
      project.add_observations(target_user.observations)
      login(target_user.login)
      get(:add_obs_modal,
          params: { project_id: project.id, candidate: target_user.id },
          format: :turbo_stream)
      assert_response(:success)
      assert_match(/None of your observations/, @response.body,
                   "Modal should show 'none' when all obs already added")
    end

    # issue #4129: one-sided date bounds must also constrain the count.
    # `no_end_date_project` has start_date = tomorrow, end_date = nil.
    # Every observation in fixtures was recorded in the past, so none
    # should match a "found on or after tomorrow" lower bound.
    def test_add_obs_modal_respects_start_date_only
      target_user = rolf
      project = projects(:no_end_date_project)
      project.user_group.users << target_user
      login(target_user.login)
      get(:add_obs_modal,
          params: { project_id: project.id, candidate: target_user.id },
          format: :turbo_stream)
      assert_response(:success)
      assert_match(/None of your observations/, @response.body,
                   "Start-date-only project should exclude obs before start")
    end

    # `no_start_date_project` has end_date = yesterday, start_date = nil.
    # Any observation recorded after yesterday should be excluded.
    def test_add_obs_modal_respects_end_date_only
      target_user = rolf
      project = projects(:no_start_date_project)
      project.user_group.users << target_user
      # Move all of target_user's obs into the future so the end_date
      # bound is what filters them out (not some other constraint).
      target_user.observations.update_all(when: Time.zone.tomorrow)
      login(target_user.login)
      get(:add_obs_modal,
          params: { project_id: project.id, candidate: target_user.id },
          format: :turbo_stream)
      assert_response(:success)
      assert_match(/None of your observations/, @response.body,
                   "End-date-only project should exclude obs after end")
    end

    # issue #4148: trust modal returns the modal component for the member
    def test_trust_modal_returns_turbo_stream_for_member
      target_user = project_members(:eol_member_katrina).user
      project = projects(:eol_project)
      login(target_user.login)
      get(:trust_modal,
          params: { project_id: project.id, candidate: target_user.id },
          format: :turbo_stream)
      assert_response(:success)
      assert_match(/modal_trust_settings/, @response.body,
                   "Modal markup should be returned in turbo stream")
    end

    # issue #4148: trust modal denies users acting on behalf of others
    def test_trust_modal_denies_non_self
      target_user = project_members(:eol_member_katrina).user
      project = projects(:eol_project)
      login(mary.login)
      get(:trust_modal,
          params: { project_id: project.id, candidate: target_user.id },
          format: :turbo_stream)
      assert_redirected_to(project_members_path(project.id))
    end

    # issue #4129: modal requires the candidate to match current user
    def test_add_obs_modal_denies_non_self
      target_user = project_members(:eol_member_katrina).user
      project = projects(:eol_project)
      login(mary.login)
      get(:add_obs_modal,
          params: { project_id: project.id, candidate: target_user.id },
          format: :turbo_stream)
      assert_redirected_to(project_members_path(project.id))
    end

    # member sharing matching observations
    def test_member_add_constrainted_obs
      target_user = project_members(:eol_member_katrina).user
      project = projects(:current_project)
      obs_count = project.observations.count
      params = {
        project_id: project.id,
        candidate: target_user.id,
        commit: :change_member_add_obs.l
      }
      put_requires_login(:update, params, target_user.login)
      assert(obs_count < project.observations.count)
    end

    # untrusting member trusting
    def test_member_trust
      target_user = project_members(:eol_member_katrina).user
      project = projects(:eol_project)
      params = {
        project_id: project.id,
        candidate: target_user.id,
        commit: :change_member_hidden_gps_trust.l
      }
      put_requires_login(:update, params, target_user.login)
      assert_equal(
        project.project_members.find_by(user: target_user).trust_level,
        "hidden_gps"
      )
    end

    # trusting member revoking trust
    def test_member_revoke_trust
      target_user = project_members(:eol_member_mary).user
      project = projects(:eol_project)
      params = {
        project_id: project.id,
        candidate: target_user.id,
        commit: :change_member_status_revoke_trust.l
      }
      put_requires_login(:update, params, target_user.login)
      assert_equal(
        project.project_members.find_by(user: target_user).trust_level,
        "no_trust"
      )
    end

    # member allows editing
    def test_member_allow_editing
      target_user = project_members(:eol_member_mary).user
      project = projects(:eol_project)
      params = {
        project_id: project.id,
        candidate: target_user.id,
        commit: :change_member_editing_trust.l
      }
      put_requires_login(:update, params, target_user.login)
      assert_equal(
        project.project_members.find_by(user: target_user).trust_level,
        "editing"
      )
    end

    # There are many other combinations that shouldn't work
    # for change_member_status, but I think the above covers the key cases

    def test_add_members
      project = projects(:eol_project)
      requires_login(:new, project_id: project.id)

      assert_displayed_title("Add users to #{project.title}",
                             "Admin should be able to see add members form")
      assert_select("td", { text: users(:zero_user).login },
                    "List of potential members should include verified users")
      assert_select("td", { text: users(:unverified).login, count: 0 },
                    "List of potential members should omit unverified users")
    end

    # Make sure non-admin cannot see form.
    def test_add_members_non_admin
      project_id = projects(:eol_project).id
      requires_login(:new, { project_id: project_id }, katrina.login)
      assert_redirected_to(project_members_path(project_id))
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
      assert_redirected_to(project_members_path(eol_project.id))
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
      assert_redirected_to(project_members_path(eol_project.id))
      target_user = User.find(target_user.id)
      assert_equal(false, target_user.in_group?(eol_project.admin_group.name))
      assert_equal(false, target_user.in_group?(eol_project.user_group.name))
    end

    def test_add_self_to_open_membership_project
      project = projects(:open_membership_project)
      target_user = dick
      assert_equal(false, target_user.in_group?(project.admin_group.name))
      assert_equal(false, target_user.in_group?(project.user_group.name))
      params = {
        project_id: project.id,
        candidate: target_user.id,
        target: :project_index
      }
      post_requires_login(:create, params, target_user.login)
      assert_redirected_to(project_path(project.id))
      target_user = User.find(target_user.id)
      assert_equal(false, target_user.in_group?(project.admin_group.name))
      assert_equal(true, target_user.in_group?(project.user_group.name))
    end

    def test_add_someone_else_to_open_membership_project
      project = projects(:open_membership_project)
      target_user = dick
      assert_equal(false, target_user.in_group?(project.admin_group.name))
      assert_equal(false, target_user.in_group?(project.user_group.name))
      params = {
        project_id: project.id,
        candidate: target_user.id
      }
      post_requires_login(:create, params, katrina.login)
      assert_redirected_to(project_members_path(project.id))
      target_user = User.find(target_user.id)
      assert_equal(false, target_user.in_group?(project.admin_group.name))
      assert_equal(false, target_user.in_group?(project.user_group.name))
    end

    def test_add_member_writein
      eol_project = projects(:eol_project)
      target_user = dick
      assert_not(target_user.in_group?(eol_project.admin_group.name))
      assert_not(target_user.in_group?(eol_project.user_group.name))
      params = {
        project_id: eol_project.id,
        candidate: target_user.unique_text_name
      }
      post_requires_login(:create, params, mary.login)
      assert_redirected_to(project_members_path(eol_project.id))
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
      assert_redirected_to(project_members_path(eol_project.id))
      assert_flash_error
      assert_equal(num_before, eol_project.reload.user_group.users.count)
    end

    def test_index
      eol_project = projects(:eol_project)
      login
      get(:index, params: { project_id: eol_project.id })

      member = eol_project.project_members.first
      assert_match(member.user.name, @response.body)
      assert_response(:success)
    end
  end
end

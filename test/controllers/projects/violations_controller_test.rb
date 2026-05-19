# frozen_string_literal: true

require("test_helper")

# Functional tests for Projects::ViolationsController. The page is keyed
# off Project::VIOLATION_KINDS (#4136); this exercises rendering and
# the four PUT actions (exclude, extend, add_target_name,
# add_target_location) plus back-compat for the legacy
# "Remove Selected" form.
module Projects
  class ViolationsControllerTest < FunctionalTestCase
    def test_index_renders_for_owner
      project = projects(:falmouth_2023_09_project)
      violations = project.violations
      assert(violations.any?,
             "Test needs Project fixture with violations")

      user = project.user
      login(user.login)
      get(:index, params: { project_id: project.id })

      assert_response(:success)
      assert_select("#content", { text: /#{project.title}/ })
      assert_select("a[href = '#{project_path(project)}']", true,
                    "Missing project link")
      violations.each do |v|
        assert_select("a[href*='#{v.obs.id}']", { count: 1 },
                      "Missing obs link for #{v.obs.id}")
      end
    end

    def test_index_no_violations
      project = projects(:eol_project)
      assert_empty(project.violations,
                   "Test needs project with no violations")

      login(project.user.login)
      get(:index, params: { project_id: project.id })

      assert_response(:success)
      assert_select("p", { text: /#{:form_violations_no_violations.l}/ })
    end

    def test_update_legacy_remove_selected
      project = projects(:falmouth_2023_09_project)
      victim = project.violations.first.obs
      params = { project_id: project.id,
                 project: { "remove_#{victim.id}" => "1" } }

      login(project.user.login)
      assert_difference("project.observations.count", -1) do
        put(:update, params: params)
      end
      assert_not_includes(project.observations, victim)
    end

    def test_update_exclude
      project = projects(:falmouth_2023_09_project)
      victim = project.violations.first.obs
      params = { project_id: project.id,
                 project: { do: "exclude", obs_id: victim.id } }

      login(project.user.login)
      put(:update, params: params)

      assert_redirected_to(project_violations_path(project_id: project.id))
      assert_includes(project.excluded_observations, victim)
      assert_not_includes(project.observations, victim)
    end

    def test_update_extend_widens_dates
      project = projects(:falmouth_2023_09_project)
      future_violation =
        project.violations.find { |v| v.kinds.include?(:date) }
      assert(future_violation, "Test needs a date violation in fixtures")
      victim = future_violation.obs
      params = { project_id: project.id,
                 project: { do: "extend", obs_id: victim.id } }

      login(project.user.login)
      put(:update, params: params)

      project.reload
      assert(project.start_date.nil? || project.start_date <= victim.when)
      assert(project.end_date.nil? || project.end_date >= victim.when)
    end

    def test_update_add_target_name
      proj = projects(:rare_fungi_project)
      proj.project_target_names.destroy_all
      proj.add_target_name(names(:agaricus))
      proj.update!(start_date: nil, end_date: nil, location: nil)
      proj.project_target_locations.destroy_all
      off_target = observations(:peltigera_obs)
      proj.add_observation(off_target)

      params = { project_id: proj.id,
                 project: { do: "add_target_name",
                            obs_id: off_target.id } }
      login(proj.user.login)
      put(:update, params: params)

      assert_redirected_to(project_violations_path(project_id: proj.id))
      assert_includes(proj.target_names.reload, off_target.name)
    end

    def test_update_add_target_location
      proj = projects(:rare_fungi_project)
      proj.project_target_locations.destroy_all
      proj.add_target_location(locations(:burbank))
      proj.update!(start_date: nil, end_date: nil, location: nil)
      proj.project_target_names.destroy_all
      elsewhere = observations(:falmouth_2023_09_obs)
      proj.add_observation(elsewhere)
      new_target = locations(:falmouth)

      params = { project_id: proj.id,
                 project: { do: "add_target_location",
                            obs_id: elsewhere.id,
                            location_id: new_target.id } }
      login(proj.user.login)
      put(:update, params: params)

      assert_redirected_to(project_violations_path(project_id: proj.id))
      assert_includes(proj.target_locations.reload, new_target)
    end

    def test_update_admin_only_actions_no_op_for_non_admin
      proj = projects(:falmouth_2023_09_project)
      stranger = users(:zero_user)
      assert_not(proj.is_admin?(stranger))
      original_start = proj.start_date
      original_end = proj.end_date
      victim = proj.violations.first.obs

      login(stranger.login)
      put(:update, params: { project_id: proj.id,
                             project: { do: "extend",
                                        obs_id: victim.id } })

      proj.reload
      assert_equal(original_start, proj.start_date,
                   "Non-admin should not be able to extend project dates")
      assert_equal(original_end, proj.end_date)
    end

    def test_update_exclude_by_obs_owner
      proj = projects(:falmouth_2023_09_project)
      victim = proj.violations.first.obs

      login(victim.user.login)
      put(:update, params: { project_id: proj.id,
                             project: { do: "exclude",
                                        obs_id: victim.id } })

      assert_redirected_to(project_violations_path(project_id: proj.id))
      assert_includes(proj.excluded_observations, victim,
                      "Obs owner can self-exclude their own violation")
    end

    def test_update_exclude_by_stranger_is_forbidden
      proj = projects(:falmouth_2023_09_project)
      victim = proj.violations.first.obs
      stranger = users(:zero_user)
      assert_not_equal(stranger, victim.user)
      assert_not(proj.is_admin?(stranger))

      login(stranger.login)
      put(:update, params: { project_id: proj.id,
                             project: { do: "exclude",
                                        obs_id: victim.id } })

      assert_not_includes(proj.excluded_observations, victim,
                          "Stranger cannot exclude someone else's obs")
    end

    def test_update_nonexistent_project
      id = -1
      params = { project_id: id,
                 project: { do: "exclude", obs_id: 0 } }
      login
      put(:update, params: params)
      assert_redirected_to(projects_path)
    end

    # ---------- target_location_modal endpoint (#4304) ----------

    def test_target_location_modal_renders_for_admin
      project = projects(:rare_fungi_project)
      project.project_target_locations.destroy_all
      project.add_target_location(locations(:burbank))
      project.update!(start_date: nil, end_date: nil, location: nil)
      project.add_observation(observations(:falmouth_2023_09_obs))
      obs = observations(:falmouth_2023_09_obs)

      login(project.user.login)
      get(:target_location_modal,
          params: { project_id: project.id, obs_id: obs.id },
          format: :turbo_stream)

      assert_response(:success)
      modal_id = Components::TargetLocationModal.modal_id_for(obs)
      assert_select("##{modal_id}", { count: 1 },
                    "Endpoint must render the Add-Target-Location modal")
    end

    def test_target_location_modal_404s_for_non_admin
      project = projects(:rare_fungi_project)
      obs = observations(:falmouth_2023_09_obs)

      login(users(:mary).login) # not admin of rare_fungi_project
      get(:target_location_modal,
          params: { project_id: project.id, obs_id: obs.id },
          format: :turbo_stream)

      assert_response(:not_found)
    end

    def test_target_location_modal_404s_for_missing_obs
      project = projects(:rare_fungi_project)
      login(project.user.login)
      get(:target_location_modal,
          params: { project_id: project.id, obs_id: -1 },
          format: :turbo_stream)

      assert_response(:not_found)
    end

    def test_target_location_modal_404s_for_missing_project
      obs = observations(:falmouth_2023_09_obs)
      login(users(:rolf).login)
      get(:target_location_modal,
          params: { project_id: -1, obs_id: obs.id },
          format: :turbo_stream)

      assert_response(:not_found)
    end
  end
end

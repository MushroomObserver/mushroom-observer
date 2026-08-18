# frozen_string_literal: true

require("test_helper")

# NOTE: params changed from
#   :project > :project_id
#   :observation > :id
module Observations
  class ProjectsControllerTest < FunctionalTestCase
    def test_edit_partitions_projects_by_membership
      obs = observations(:coprinus_comatus_obs)
      member_project = projects(:eol_project)
      assert(member_project.member?(rolf))
      member_project.add_observation(obs)
      login("rolf")

      get(:edit, params: { id: obs.id })
      assert_response(:success)

      obs_ids = assigns(:obs_projects).map(&:id)
      other_ids = assigns(:other_projects).map(&:id)
      assert_includes(obs_ids, member_project.id,
                      "Project containing the obs belongs in obs_projects")
      assert_not_includes(other_ids, member_project.id)
      other_ids.each do |id|
        assert_not(Project.find(id).observations.member?(obs))
      end
    end

    def test_add_observation_to_project
      proj = projects(:eol_project)
      obs = observations(:coprinus_comatus_obs)
      assert_not(proj.observations.member?(obs))
      params = { id: obs.id, project_id: proj.id, commit: "add" }

      login("rolf")
      put(:update, params: params)

      assert_redirected_to(project_path(proj.id))
      assert(proj.reload.observations.member?(obs))
    end

    def test_add_observation_to_project_no_permission
      proj = projects(:eol_project)
      obs = observations(:coprinus_comatus_obs)
      assert_not(proj.observations.member?(obs))
      params = { id: obs.id, project_id: proj.id, commit: "add" }

      login("dick")
      put(:update, params: params)

      assert_redirected_to(project_path(proj.id))
      assert_not(proj.reload.observations.member?(obs))
    end

    def test_add_observation_to_project_invalid_mode
      proj = projects(:eol_project)
      obs = observations(:coprinus_comatus_obs)
      assert_not(proj.observations.member?(obs))
      params = { id: obs.id, project_id: proj.id, commit: "invalid_param" }

      login("rolf")
      put(:update, params: params)

      assert_flash_error
      # Same-URL re-render needs non-2xx or Turbo hangs (see
      # .claude/rules/turbo_submit_forms.md).
      assert_unprocessable
      assert_not(proj.reload.observations.member?(obs))
    end

    def test_remove_observation_from_project
      proj = projects(:eol_project)
      obs = observations(:coprinus_comatus_obs)
      proj.add_observation(obs)
      params = { id: obs.id, project_id: proj.id, commit: "remove" }

      login("dick")
      put(:update, params: params)
      assert_redirected_to(project_path(proj.id))
      assert(proj.reload.observations.member?(obs),
             "Non-member should not be able to remove the observation")

      login("rolf")
      put(:update, params: params)
      assert_redirected_to(project_path(proj.id))
      assert_not(proj.reload.observations.member?(obs))
    end

    def test_edit_renders_add_and_remove_forms
      member_proj = projects(:eol_project)
      other_proj = projects(:bolete_project)
      other_proj.add_administrator(rolf)
      obs = observations(:coprinus_comatus_obs)
      member_proj.add_observation(obs)
      login("rolf")

      get(:edit, params: { id: obs.id })

      assert_select(
        "form[action=?]",
        observation_project_path(id: obs.id, project_id: member_proj.id,
                                 commit: "remove"),
        count: 1
      )
      assert_select(
        "form[action=?]",
        observation_project_path(id: obs.id, project_id: other_proj.id,
                                 commit: "add"),
        count: 1
      )
    end
  end
end

# frozen_string_literal: true

require("test_helper")

module Projects
  class UpdatesControllerTest < FunctionalTestCase
    def setup
      super
      @project = projects(:rare_fungi_project)
      # Add an observation matching a target name
      @matching_obs = observations(:coprinus_comatus_obs)
      login("rolf")
    end

    def test_index_as_admin
      get(:index, params: { project_id: @project.id })

      assert_response(:success)
    end

    def test_index_as_non_admin
      login("mary")

      get(:index, params: { project_id: @project.id })

      assert_redirected_to(project_path(@project))
    end

    def test_index_shows_matching_observations
      get(:index, params: { project_id: @project.id })

      assert_response(:success)
    end

    def test_add_observation
      assert_not_includes(@project.observations, @matching_obs)

      post(:add_observation,
           params: { project_id: @project.id,
                     id: @matching_obs.id })

      assert_includes(@project.observations.reload, @matching_obs)
    end

    def test_add_observation_turbo_stream
      post(:add_observation,
           params: { project_id: @project.id,
                     id: @matching_obs.id,
                     format: :turbo_stream })

      assert_response(:success)
      assert_includes(@project.observations.reload, @matching_obs)
    end

    def test_remove_observation
      @project.add_observation(@matching_obs)
      assert_includes(@project.observations, @matching_obs)

      delete(:remove_observation,
             params: { project_id: @project.id,
                       id: @matching_obs.id })

      assert_not_includes(@project.observations.reload, @matching_obs)
    end

    def test_remove_observation_turbo_stream
      @project.add_observation(@matching_obs)

      delete(:remove_observation,
             params: { project_id: @project.id,
                       id: @matching_obs.id,
                       format: :turbo_stream })

      assert_response(:success)
      assert_not_includes(@project.observations.reload, @matching_obs)
    end

    def test_add_all
      post(:add_all, params: { project_id: @project.id })

      assert_redirected_to(
        project_updates_path(project_id: @project.id)
      )
      assert_flash(/Added/)
    end

    def test_clear
      @project.add_observation(@matching_obs)

      delete(:clear, params: { project_id: @project.id })

      assert_redirected_to(
        project_updates_path(project_id: @project.id)
      )
      assert_flash(/Removed/)
    end

    def test_add_observation_not_found
      post(:add_observation,
           params: { project_id: @project.id,
                     id: 999_999 })

      assert_response(:not_found)
    end

    def test_remove_observation_not_found
      delete(:remove_observation,
             params: { project_id: @project.id,
                       id: 999_999 })

      assert_response(:not_found)
    end
  end
end

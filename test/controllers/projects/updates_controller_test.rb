# frozen_string_literal: true

require("test_helper")

module Projects
  class UpdatesControllerTest < FunctionalTestCase
    def setup
      super
      @project = projects(:rare_fungi_project)
      # An observation matching a target name AND target location
      @matching_obs = observations(:agaricus_campestris_obs)
      login("rolf")
    end

    def test_index_as_admin
      get(:index, params: { project_id: @project.id })

      assert_response(:success)
    end

    def test_index_with_pagination
      burbank = locations(:burbank)
      name = names(:coprinus_comatus)
      2.times do
        Observation.create!(name: name, user: users(:rolf),
                            location: burbank, when: Time.zone.now)
      end
      users(:rolf).update!(layout_count: 1)

      get(:index, params: { project_id: @project.id })

      assert_response(:success)
    end

    def test_index_as_non_admin
      login("mary")

      get(:index, params: { project_id: @project.id })

      assert_redirected_to(project_path(@project))
    end

    def test_index_default_hides_excluded
      @project.exclude_observation(@matching_obs)

      get(:index, params: { project_id: @project.id })

      assert_response(:success)
      assert_not_includes(assigns_matrix_observations, @matching_obs)
    end

    def test_index_show_excluded
      @project.exclude_observation(@matching_obs)

      get(:index, params: { project_id: @project.id, show_excluded: "1" })

      assert_response(:success)
    end

    def test_add_observation
      assert_not_includes(@project.observations, @matching_obs)

      post(:add_observation,
           params: { project_id: @project.id,
                     id: @matching_obs.id })

      assert_includes(@project.observations.reload, @matching_obs)
    end

    def test_add_observation_un_excludes
      @project.exclude_observation(@matching_obs)
      assert_includes(@project.excluded_observations, @matching_obs)

      post(:add_observation,
           params: { project_id: @project.id,
                     id: @matching_obs.id })

      assert_not_includes(@project.excluded_observations.reload, @matching_obs)
      assert_includes(@project.observations.reload, @matching_obs)
    end

    def test_exclude_observation
      post(:exclude_observation,
           params: { project_id: @project.id,
                     id: @matching_obs.id })

      assert_includes(@project.excluded_observations.reload, @matching_obs)
    end

    def test_exclude_observation_from_project
      @project.add_observation(@matching_obs)

      post(:exclude_observation,
           params: { project_id: @project.id,
                     id: @matching_obs.id })

      assert_not_includes(@project.observations.reload, @matching_obs)
      assert_includes(@project.excluded_observations.reload, @matching_obs)
    end

    def test_exclude_observation_turbo_stream
      post(:exclude_observation,
           params: { project_id: @project.id,
                     id: @matching_obs.id,
                     format: :turbo_stream })

      assert_response(:success)
      assert_includes(@project.excluded_observations.reload, @matching_obs)
    end

    def test_exclude_observation_not_found
      post(:exclude_observation,
           params: { project_id: @project.id,
                     id: 999_999 })

      assert_response(:not_found)
    end

    def test_add_all
      post(:add_all, params: { project_id: @project.id })

      assert_redirected_to(
        project_updates_path(project_id: @project.id,
                             show_excluded: false)
      )
      assert_flash(/Added/)
    end

    def test_add_all_with_show_excluded
      @project.exclude_observation(@matching_obs)

      post(:add_all, params: { project_id: @project.id,
                               show_excluded: "1" })

      assert_includes(@project.observations.reload, @matching_obs)
      assert_not_includes(@project.excluded_observations.reload, @matching_obs)
    end

    def test_add_observation_not_found
      post(:add_observation,
           params: { project_id: @project.id,
                     id: 999_999 })

      assert_response(:not_found)
    end

    private

    # Helper to pull observations from the rendered view for assertions.
    def assigns_matrix_observations
      # Parse matrix box ids from response body.
      response.body.scan(/id="box_(\d+)"/).map do |match|
        Observation.find(match.first.to_i)
      end
    end
  end
end

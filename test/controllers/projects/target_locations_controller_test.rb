# frozen_string_literal: true

require("test_helper")

module Projects
  class TargetLocationsControllerTest < FunctionalTestCase
    def test_create_single_location_as_admin
      project = projects(:rare_fungi_project)
      location = locations(:albion)
      login("rolf")

      assert_not_includes(project.target_locations, location)

      post(:create, params: {
             project_id: project.id,
             project_target_locations_add: { locations: location.name }
           })

      assert_includes(project.target_locations.reload, location)
    end

    def test_create_multiple_locations
      project = projects(:rare_fungi_project)
      login("rolf")

      input = "#{locations(:albion).name}\n#{locations(:gualala).name}"
      post(:create, params: {
             project_id: project.id,
             project_target_locations_add: { locations: input }
           })

      assert_includes(project.target_locations.reload,
                      locations(:albion))
      assert_includes(project.target_locations,
                      locations(:gualala))
    end

    def test_create_turbo_stream
      project = projects(:rare_fungi_project)
      location = locations(:albion)
      login("rolf")

      post(:create, params: {
             project_id: project.id,
             project_target_locations_add: { locations: location.name },
             format: :turbo_stream
           })

      assert_response(:success)
      assert_includes(project.target_locations.reload, location)
    end

    def test_create_as_non_admin
      project = projects(:rare_fungi_project)
      location = locations(:albion)
      login("mary")

      post(:create, params: {
             project_id: project.id,
             project_target_locations_add: { locations: location.name }
           })

      assert_redirected_to(
        project_locations_path(project_id: project.id)
      )
      assert_not_includes(project.target_locations.reload, location)
    end

    def test_create_with_invalid_location
      project = projects(:rare_fungi_project)
      login("rolf")

      post(:create, params: {
             project_id: project.id,
             project_target_locations_add: { locations: "Nonexistent Place" }
           })

      assert_flash_error
    end

    def test_destroy_as_admin
      project = projects(:rare_fungi_project)
      location = locations(:burbank)
      login("rolf")

      assert_includes(project.target_locations, location)

      delete(:destroy, params: { project_id: project.id,
                                 id: location.id })

      assert_not_includes(project.target_locations.reload, location)
    end

    def test_destroy_turbo_stream
      project = projects(:rare_fungi_project)
      location = locations(:burbank)
      login("rolf")

      delete(:destroy, params: { project_id: project.id,
                                 id: location.id,
                                 format: :turbo_stream })

      assert_response(:success)
      assert_not_includes(project.target_locations.reload, location)
    end

    def test_destroy_with_invalid_location
      project = projects(:rare_fungi_project)
      login("rolf")

      delete(:destroy, params: { project_id: project.id,
                                 id: 999_999 })

      assert_flash_error
    end

    def test_destroy_as_non_admin
      project = projects(:rare_fungi_project)
      location = locations(:burbank)
      login("mary")

      delete(:destroy, params: { project_id: project.id,
                                 id: location.id })

      assert_redirected_to(
        project_locations_path(project_id: project.id)
      )
      assert_includes(project.target_locations.reload, location)
    end
  end
end

# frozen_string_literal: true

require("test_helper")

module Projects
  class LocationsControllerTest < FunctionalTestCase
    def test_index
      eol_project = projects(:eol_project)
      login
      get(:index, params: { project_id: eol_project.id })

      loc = eol_project.locations.first
      assert_match(loc.display_name, @response.body)
      assert_response(:success)
    end

    def test_index_scientific
      eol_project = projects(:eol_project)
      login("roy")
      get(:index, params: { project_id: eol_project.id })

      loc = eol_project.locations.first
      assert_match(loc.display_name, @response.body)
      assert_response(:success)
    end

    def test_index_with_target_locations
      project = projects(:rare_fungi_project)
      login
      get(:index, params: { project_id: project.id })

      assert_response(:success)
      target = locations(:burbank)
      # Target location name should appear even with no obs
      assert_match(target.display_name, @response.body)
    end

    def test_index_without_target_locations
      project = projects(:eol_project)
      login
      get(:index, params: { project_id: project.id })

      assert_response(:success)
      # No collapse elements when there are no targets
      assert_no_match(/panel-collapse-trigger/, @response.body)
    end
  end
end

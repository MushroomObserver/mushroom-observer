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
      assert_template("index")
    end

    def test_index_scientific
      eol_project = projects(:eol_project)
      login("roy")
      get(:index, params: { project_id: eol_project.id })

      loc = eol_project.locations.first
      assert_match(loc.display_name, @response.body)
      assert_template("index")
    end
  end
end

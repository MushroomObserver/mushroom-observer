# frozen_string_literal: true

require("test_helper")

# tests of Herbarium controller
module Projects
  class ViolationsControllerTest < FunctionalTestCase
    def test_index
      project = projects(:falmouth_2023_09_project)
      violations_count = project.count_violations
      assert(violations_count.positive?,
             "Test needs Project fixture with constraint violations")
      user = project.user

      login(user.login)
      get(:index, params: { project_id: project.id })

      assert_response(:success)
    end
  end
end

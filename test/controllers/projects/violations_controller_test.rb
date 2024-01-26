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

      assert_select("#title", { text: /#{project.title}/ },
                    "Page title should include project name")

      assert_select("#constraints_summary", { text: /#{:CONSTRAINTS.l}/ })
      assert_select(
        "#constraints_summary", { text: /#{project.date_range}/ },
        "Missing Project date range"
      )
      assert_select(
        "#constraints_summary",
        { text: /#{project.location.north} \S+ #{project.location.south}/ },
        "Missing Project latitude range"
      )
      assert_select(
        "#constraints_summary",
        { text: /#{project.location.west} \S+ #{project.location.east}/ },
        "Missing Project longitude rants"
      )
    end
  end
end

# frozen_string_literal: true

require("test_helper")

# tests of Herbarium controller
module Projects
  class ViolationsControllerTest < FunctionalTestCase
    def test_edit
      project = projects(:falmouth_2023_09_project)
      violations_count = project.count_violations
      assert(violations_count.positive?,
             "Test needs Project fixture with constraint violations")
      assert(project.observations.count > violations_count,
             "Test need Project fixture with compliant Observation(s)")
      compliant_observation = observations(:falmouth_2023_09_obs)
      user = project.user

      login(user.login)
      get(:edit, params: { id: project.id })

      assert_response(:success)

      assert_select("#content", { text: /#{project.title}/ },
                    "Page should include project name")
      assert_select("#content", { text: /#{:CONSTRAINTS.l}/ })
      assert_select("#content", { text: /#{project.date_range}/ },
                    "Missing Project date range")
      assert_select(
        "#content",
        { text: /#{project.location.north} \S+ #{project.location.south}/ },
        "Missing Project latitude range"
      )
      assert_select(
        "#content",
        { text: /#{project.location.west} \S+ #{project.location.east}/ },
        "Missing Project longitude range"
      )
      project.violations.each do |violation|
        assert_select(
          "#violations a[href *= '#{violation.id}']", { count: 1 },
          "Non-compliant list should have a link to Observation #{violation.id}"
        )
      end

      assert_select(
        "#violations a[href *= '#{compliant_observation.id}']", { count: 0 },
        "Non-compliant list should not link to compliant Observation"
      )
    end
  end
end

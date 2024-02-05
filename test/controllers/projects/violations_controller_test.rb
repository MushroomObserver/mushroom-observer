# frozen_string_literal: true

require("test_helper")

# tests of Herbarium controller
module Projects
  class ViolationsControllerTest < FunctionalTestCase
    def test_edit_by_owner
      project = projects(:falmouth_2023_09_project)
      violations = project.violations
      violations_count = violations.size
      assert(violations_count.positive?,
             "Test needs Project fixture with constraint violations")
      assert(project.observations.count > violations_count,
             "Test need Project fixture with compliant Observation(s)")
      compliant_observation = observations(:falmouth_2023_09_obs)
      hidden_obs = observations(:brett_woods_2023_09_obs)
      assert(hidden_obs.gps_hidden &&
             violations.include?(hidden_obs) &&
             !project.location.found_here?(hidden_obs),
             "Test needs obs with hidden gps, outside project location")

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
      assert_select(
        "#violations", { text: /#{hidden_obs.lat}/, count: 1 },
        "Violation list should display hidden geoloc to trusted user"
      )
    end

    def test_edit_by_non_member
      project = projects(:falmouth_2023_09_project)
      violations = project.violations
      hidden_obs = observations(:brett_woods_2023_09_obs)
      assert(hidden_obs.gps_hidden &&
             violations.include?(hidden_obs) &&
             !project.location.found_here?(hidden_obs),
             "Test needs obs with hidden gps, outside project location")
      user = users(:zero_user)

      login(user.login)
      get(:edit, params: { id: project.id })

      violations.each do |violation|
        assert_select(
          "#violations a[href *= '#{violation.id}']", { count: 1 },
          "Non-compliant list should have a link to Observation #{violation.id}"
        )
      end

      assert_select(
        "#violations", { text: /#{hidden_obs.lat}/, count: 0 },
        "Violation list should hide hidden geoloc from untrusted user"
      )
    end
  end
end

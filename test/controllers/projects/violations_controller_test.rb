# frozen_string_literal: true

require("test_helper")

# tests of Herbarium controller
module Projects
  class ViolationsControllerTest < FunctionalTestCase
    def test_index_by_owner
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
      get(:index, params: { project_id: project.id })

      assert_response(:success)
      assert_form_action(action: :update)

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
          "#project_violations_form a[href *= '#{violation.id}']", { count: 1 },
          "Non-compliant list should have a link to Observation #{violation.id}"
        )
        assert_select(
          "input[type=checkbox][id *= '#{violation.id}']",
          { count: 1 },
          "Non-compliant list should have a checkbox for Obs #{violation.id}"
        )
      end

      assert_select(
        "#project_violations_form a[href *= '#{compliant_observation.id}']",
        { count: 0 },
        "Non-compliant list should not link to compliant Observation"
      )
      assert_select(
        "#project_violations_form", { text: /#{hidden_obs.lat}/, count: 1 },
        "Violation list should display hidden geoloc to trusted user"
      )
    end

    def test_index_by_member
      project = projects(:falmouth_2023_09_project)
      violations = project.violations
      violations_count = violations.size
      assert(violations_count.positive?,
             "Test needs Project fixture with constraint violations")
      user = users(:roy)
      assert(project.member?(user) && !project.is_admin?(user) &&
             violations.map(&:user).include?(user) &&
             violations.map(&:user).uniq.size > 1,
             "Test needs non-admin project member user with violation(s) " \
             "who isn't the only person with violation")

      login(user.login)
      get(:index, params: { project_id: project.id })

      assert_response(:success)

      project.violations.each do |violation|
        assert_select(
          "#project_violations_form a[href *= '#{violation.id}']", { count: 1 },
          "Non-compliant list should have a link to Observation #{violation.id}"
        )
        if violation.user == user
          assert_select(
            "input[type=checkbox][id *= '#{violation.id}']",
            { count: 1 },
            "Non-compliant list should have a checkbox for Obs #{violation.id}"
          )
        else
          assert_select(
            "input[type=checkbox][id *= '#{violation.id}']",
            { count: 0 },
            "Non-compliant list should omit a checkbox for Obs #{violation.id}"
          )
        end
      end
    end

    def test_index_by_non_member
      project = projects(:falmouth_2023_09_project)
      violations = project.violations
      hidden_obs = observations(:brett_woods_2023_09_obs)
      assert(hidden_obs.gps_hidden &&
             violations.include?(hidden_obs) &&
             !project.location.found_here?(hidden_obs),
             "Test needs obs with hidden gps, outside project location")
      user = users(:zero_user)

      login(user.login)
      get(:index, params: { project_id: project.id })

      violations.each do |violation|
        assert_select(
          "#project_violations_form a[href *= '#{violation.id}']", { count: 1 },
          "Non-compliant list should have a link to Observation #{violation.id}"
        )
      end

      assert_select(
        "#project_violations_form", { text: /#{hidden_obs.lat}/, count: 0 },
        "Violation list should hide hidden geoloc from untrusted user"
      )
    end

    def test_update
      project = projects(:falmouth_2023_09_project)
      violations = project.violations
      assert(violations.size > 1,
             "Test needs Project fixture with multiple violations")
      nybg_2023_09_obs = observations(:nybg_2023_09_obs)
      assert(violations.include?(nybg_2023_09_obs))

      params = { project_id: project.id,
                 project: { "remove_#{nybg_2023_09_obs.id}" => "1" } }

      login(project.user.login)
      assert_difference(
        "project.violations.count", -1,
        "Failed to remove exactly one Obs from Project"
      ) do
        post(:update, params: params)
      end

      assert_not_includes(project.observations, nybg_2023_09_obs,
                          "Failed to remove checked violation from Project")
    end
  end
end

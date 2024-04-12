# frozen_string_literal: true

require("test_helper")

# Test relating to projects
class FieldSlipsIntegrationTest < CapybaraIntegrationTestCase
  def test_new_observation_violates_project_constraints
    project = projects(:falmouth_2023_09_project)
    user = users(:roy)
    assert(project.member?(user),
           "Test needs user who is member of #{project.title} Project")

    login(user)
    visit("/qr/NFAL-0001")
    click_on(:field_slip_create_obs.l)

    fill_in(:WHERE.l, with: locations(:albion).name)
    assert_no_difference(
      "Observation.count",
      "Observation shouldn't be created before confirming constraint violation"
    ) do
      first(:button, "Create").click
    end
  end
end

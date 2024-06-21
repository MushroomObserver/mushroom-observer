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

  def test_create_update_delete_field_slip
    field_slip = field_slips(:field_slip_one)

    login!(mary)
    visit(field_slips_url)
    assert_selector("h1", text: :FIELD_SLIPS.t)

    first(class: /field_slip_link_/).click
    assert_text(:field_slip_index.t)

    click_on(:field_slip_edit.t, match: :first)

    fill_in(:field_slip_code.t, with: field_slip.code)
    select(field_slip.project.title, from: :PROJECT.t)
    click_on(:field_slip_keep_obs.t)

    assert_text(:field_slip_updated.t)

    visit(field_slip_url(field_slip))
    click_on(:field_slip_destroy.t, match: :first)

    assert_text(:field_slip_destroyed.t)
  end
end

# frozen_string_literal: true

require("test_helper")

# Tests relating to field_slip UI, and projects
class FieldSlipsIntegrationTest < CapybaraIntegrationTestCase
  setup do
    @field_slip = field_slips(:field_slip_one)
  end

  def test_visiting_the_index
    login!(mary)
    visit(field_slips_url)
    assert_match(:FIELD_SLIP.t, page.title)
  end

  def test_navigating_to_show_field_slip
    login!(mary)
    visit(field_slips_url)
    first(class: /field_slip_link_/).click
    assert_text(:INDEX_OBJECT.t(type: :field_slips))
  end

  def test_updating_a_field_slip
    login!(mary)
    visit(field_slip_url(@field_slip))

    click_on(:field_slip_edit.t, match: :first)

    fill_in(:field_slip_code.t, with: @field_slip.code)
    select(@field_slip.project.title, from: :PROJECT.t)
    click_on(:field_slip_keep_obs.t)

    assert_text(:field_slip_updated.t)
  end

  def test_destroying_a_field_slip
    login!(mary)
    visit(field_slip_url(@field_slip))
    click_on(:DESTROY.t, match: :first)

    assert_text(:field_slip_destroyed.t)
  end

  def test_new_observation_violates_project_constraints
    project = projects(:falmouth_2023_09_project)
    wrong_location = locations(:albion)
    user = users(:roy)
    assert(project.member?(user),
           "Test needs user who is member of #{project.title} Project")

    login(user)
    visit("/qr/NFAL-0001")
    click_on(:field_slip_add_images.l)

    project_checkbox = "project_id_#{project.id}"
    check(project_checkbox)
    assert_selector("##{project_checkbox}[checked='checked']")
    fill_in(:WHERE.l, with: wrong_location.name, visible: :any)
    # this is what counts, would be handled by js
    find_field(id: "observation_location_id",
               type: :hidden).set(wrong_location.id)

    assert_no_difference(
      "Observation.count",
      "Observation shouldn't be created before confirming constraint violation"
    ) do
      first(:button, "Create").click
    end
  end
end

# frozen_string_literal: true

require("application_system_test_case")

class ProjectAliasFormSystemTest < ApplicationSystemTestCase
  def test_type_switch_shows_correct_autocompleter
    rolf = users(:rolf)
    project = projects(:eol_project)
    login!(rolf)

    visit(new_project_alias_path(project_id: project.id))

    # Form should be present
    assert_selector("#project_alias_form")

    # By default, location type is selected (first option alphabetically
    # is "Location" in our select)
    # Location autocompleter should be visible, user autocompleter hidden
    assert_selector("[data-type-switch-type='location']:not(.d-none)")
    assert_selector("[data-type-switch-type='user'].d-none", visible: :all)

    # Switch to User type
    select(:USER.l, from: "project_alias[target_type]")

    # Now user autocompleter should be visible, location hidden
    assert_selector("[data-type-switch-type='user']:not(.d-none)")
    assert_selector("[data-type-switch-type='location'].d-none", visible: :all)

    # Switch back to Location
    select(:LOCATION.l, from: "project_alias[target_type]")

    # Location visible again, user hidden
    assert_selector("[data-type-switch-type='location']:not(.d-none)")
    assert_selector("[data-type-switch-type='user'].d-none", visible: :all)
  end
end

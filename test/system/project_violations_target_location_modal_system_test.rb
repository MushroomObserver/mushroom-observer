# frozen_string_literal: true

require("application_system_test_case")

# End-to-end coverage for the Add-Target-Location modal flow on the
# project violations page (#4304). This is the "nice-to-have" system
# test deferred in PR #4307's test plan.
#
# Covers the two behaviors the pre-#4304 modal didn't have:
#
# 1. The "Create" link on a disabled (missing-suffix) row opens
#    `/locations/new?where=<suffix>` in a new tab AND dismisses the
#    parent modal in the current tab. Dismiss runs through Stimulus
#    `modal#hide`, not Bootstrap's `data-dismiss`, because the
#    Bootstrap handler chain preventDefaults the click and suppresses
#    `target="_blank"`.
#
# 2. Re-opening the modal after the admin has created the missing
#    suffix Location (in the other tab) reflects fresh DB state — the
#    previously-disabled radio is now enabled with the new Location's
#    id. This is the `modal-toggle` controller's `alwaysFresh` mode:
#    each open re-fetches via the
#    `Projects::ViolationsController#target_location_modal` endpoint.
class ProjectViolationsTargetLocationModalSystemTest < ApplicationSystemTestCase
  def test_create_link_opens_new_tab_and_reopen_picks_up_fresh_location
    project, obs, modal_id, missing_suffix = setup_project_with_violation
    login!(project.user)
    visit(project_violations_path(project_id: project.id))

    # ---- First open: missing-suffix row is disabled, with a Create link.
    open_target_location_modal(project, obs)
    assert_disabled_row_with_create_link(modal_id, missing_suffix)

    # ---- Clicking Create opens a new tab at /locations/new?where=<suffix>
    #      AND closes the modal in the current tab.
    new_tab = window_opened_by do
      within("##{modal_id}") do
        click_link(:form_violations_modal_target_location_create.l)
      end
    end
    within_window(new_tab) do
      assert_match(%r{/locations/new\?where=Massachusetts}, current_url)
    end
    new_tab.close
    switch_to_window(windows.first)
    assert_no_selector("##{modal_id}", visible: true, wait: 3)

    # ---- Simulate the admin completing the new Location form in the
    #      other tab. The location form's own system test covers that
    #      flow; here we just need the row to exist so the modal's
    #      next open picks it up.
    new_location = Location.create!(
      user: project.user, name: missing_suffix,
      north: 42.89, south: 41.24, east: -69.93, west: -73.51
    )

    # ---- Reopen — alwaysFresh re-fetches and the disabled row is now
    #      an enabled radio carrying the freshly-created Location id.
    open_target_location_modal(project, obs)
    within("##{modal_id}") do
      assert_selector(
        "input[type='radio'][value='#{new_location.id}']:not([disabled])"
      )
      # No Create links anywhere in the fresh modal — both suffixes
      # now point at existing Locations.
      assert_no_selector("a[target='_blank']")

      find("input[type='radio'][value='#{new_location.id}']").click
      click_button(:form_violations_modal_target_location_submit.l)
    end

    assert_current_path(project_violations_path(project_id: project.id))
    project.target_locations.reload
    assert_includes(
      project.target_locations, new_location,
      "Submitting the modal should add the new Location to target_locations"
    )
  end

  private

  # falmouth_2023_09_obs.location.name is "Falmouth, Massachusetts, USA".
  # With burbank as the only target_location, the obs has a
  # target_location violation; the modal's radio choices are the
  # comma-suffixes of that name (minus the bare-country "USA"):
  #   - "Falmouth, Massachusetts, USA"  (exists  - enabled radio)
  #   - "Massachusetts, USA"            (missing - disabled, with Create)
  def setup_project_with_violation
    project = projects(:rare_fungi_project)
    project.project_target_locations.destroy_all
    project.add_target_location(locations(:burbank))
    project.update!(start_date: nil, end_date: nil, location: nil)
    project.project_target_names.destroy_all
    obs = observations(:falmouth_2023_09_obs)
    project.add_observation(obs)
    [project, obs, Views::Controllers::Projects::Violations::TargetLocationForm.modal_id_for(obs),
     "Massachusetts, USA"]
  end

  # Disambiguate by the trigger's href — there may be other violating
  # observations on the page, each with its own Add-Target-Location link.
  def open_target_location_modal(project, obs)
    click_link(
      :form_violations_action_add_target_location.l,
      href: target_location_modal_project_violations_path(
        project_id: project.id, obs_id: obs.id
      )
    )
  end

  # Locate the row by the radio input's `value` attribute rather than by
  # label text — the "Falmouth, Massachusetts, USA" row's text also
  # contains the substring "Massachusetts, USA", so `find(".radio",
  # text: ...)` is ambiguous.
  def assert_disabled_row_with_create_link(modal_id, missing_suffix)
    within("##{modal_id}") do
      assert_selector(
        "input[type='radio'][value='#{missing_suffix}'][disabled]"
      )
      # The Create link is appended to the disabled row's .radio div
      # (per-row append). Match by its target+href shape so we don't
      # have to scope `within` a sibling-relationship to the input.
      create_link = find(
        "a[target='_blank'][href*='where=Massachusetts']"
      )
      assert_match(%r{/locations/new\?where=Massachusetts},
                   create_link[:href])
      # Modal dismiss runs through Stimulus, not Bootstrap, so the
      # link's target=_blank actually opens a new tab.
      assert_equal("click->modal#hide", create_link["data-action"])
    end
  end
end

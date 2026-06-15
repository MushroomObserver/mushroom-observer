# frozen_string_literal: true

require("application_system_test_case")

# Exercises the occurrence edit form's UI in a real browser:
# - the page loads and renders members + (when present) candidates
# - members start with checked Include + correct primary radio
# - the inline primary-obs detail section renders
# - clicking the secondary obs's Include + submitting actually
#   removes it from the occurrence (round-trip through update)
# - clicking a different obs's primary radio + submitting actually
#   reassigns the primary observation
#
# The new-form flow is covered by `occurrence_form_system_test.rb`;
# this file is the edit-flow counterpart.
class OccurrenceEditFormSystemTest < ApplicationSystemTestCase
  def test_edit_form_renders_members_and_inline_details
    rolf = users("rolf")
    primary_obs = observations(:detailed_unknown_obs)
    secondary_obs = observations(:coprinus_comatus_obs)
    occ = create_occurrence_with(rolf, primary_obs, secondary_obs)

    login!(rolf)
    visit("/occurrences/#{occ.id}/edit")
    assert_selector("#occurrence_form")

    # Both observations show as checked Include checkboxes.
    assert(checkbox_for(primary_obs).checked?,
           "Primary obs should start checked")
    assert(checkbox_for(secondary_obs).checked?,
           "Secondary obs should start checked")

    # Primary observation's primary radio is selected.
    assert(radio_for(primary_obs).checked?,
           "Primary obs's primary radio should be selected")

    # Inline primary-obs detail section is present (date picker is
    # always shown; location select only when >1 distinct location).
    assert_selector(
      "select[name='occurrence[primary_observation][when(3i)]']"
    )
  end

  def test_edit_form_renders_candidates_from_recent_observations
    rolf = users("rolf")
    primary_obs = observations(:detailed_unknown_obs)
    candidate_obs = observations(:coprinus_comatus_obs)
    occ = create_occurrence_with(rolf, primary_obs)

    # Candidates come from the user's recent ObservationViews that
    # aren't already in the occurrence (see
    # `OccurrencesController::Edit#candidate_observations`).
    candidate_obs.update!(occurrence: nil)
    ObservationView.create!(user: rolf, observation: candidate_obs,
                            last_view: 30.minutes.ago)

    login!(rolf)
    visit("/occurrences/#{occ.id}/edit")

    assert_text(:edit_occurrence_add_heading.l)
    assert_selector(
      "input[type='checkbox']" \
      "[name='occurrence[observation_ids][]']" \
      "[value='#{candidate_obs.id}']",
      visible: false
    )
  end

  def test_unchecking_include_and_submitting_removes_observation
    rolf = users("rolf")
    # Need 3 obs so removing one leaves 2 — otherwise the controller
    # destroys the occurrence (too-few-to-keep), redirecting to the
    # observation page (different path, makes assertions noisier).
    primary_obs = observations(:detailed_unknown_obs)
    other1 = observations(:coprinus_comatus_obs)
    other2 = observations(:agaricus_campestris_obs)
    occ = create_occurrence_with(rolf, primary_obs, other1, other2)

    login!(rolf)
    visit("/occurrences/#{occ.id}/edit")
    assert_selector("#occurrence_form")

    # Uncheck other1 (Stimulus `includeToggled` fires via the
    # data-action attribute on the checkbox).
    checkbox_for(other1).click

    click_button(:edit_occurrence_submit.l)
    # Wait for the redirect away from edit (controller redirects to
    # occurrence#show on success, or re-renders edit on project gaps;
    # the assertion below holds in either case).
    assert_flash_success

    occ.reload
    assert_includes(occ.observations, primary_obs,
                    "Primary should still be a member")
    assert_includes(occ.observations, other2,
                    "other2 should still be a member")
    assert_not_includes(occ.observations, other1,
                        "other1 should have been removed")
  end

  def test_changing_primary_and_submitting_reassigns_primary
    rolf = users("rolf")
    primary_obs = observations(:detailed_unknown_obs)
    secondary_obs = observations(:coprinus_comatus_obs)
    occ = create_occurrence_with(rolf, primary_obs, secondary_obs)

    login!(rolf)
    visit("/occurrences/#{occ.id}/edit")

    # Click the secondary obs's primary radio (Stimulus
    # `primarySelected` fires via data-action on the radio).
    radio_for(secondary_obs).click

    click_button(:edit_occurrence_submit.l)
    # Wait for the success flash (controller may redirect to
    # occurrence#show OR re-render edit if project_gaps exist; the
    # data-level assertion below holds in either case).
    assert_flash_success

    occ.reload
    assert_equal(secondary_obs, occ.primary_observation,
                 "Primary observation should have switched")
  end

  private

  def create_occurrence_with(user, primary, *others)
    occ = Occurrence.create!(user: user,
                             primary_observation: primary)
    primary.update!(occurrence: occ)
    others.each { |o| o.update!(occurrence: occ) }
    occ
  end

  def checkbox_for(obs)
    find("input[type='checkbox']" \
         "[name='occurrence[observation_ids][]']" \
         "[value='#{obs.id}']",
         visible: false)
  end

  def radio_for(obs)
    find("input[type='radio']" \
         "[name='occurrence[primary_observation_id]']" \
         "[value='#{obs.id}']",
         visible: false)
  end
end

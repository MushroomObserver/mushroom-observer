# frozen_string_literal: true

require("application_system_test_case")

class OccurrenceFormSystemTest < ApplicationSystemTestCase
  def test_create_occurrence_submits_form
    rolf = users("rolf")
    obs1 = observations(:minimal_unknown_obs)
    obs2 = observations(:coprinus_comatus_obs)

    ObservationView.create!(user: rolf, observation: obs1,
                            last_view: 1.hour.ago)
    ObservationView.create!(user: rolf, observation: obs2,
                            last_view: 30.minutes.ago)

    login!(rolf)
    visit("/occurrences/new?observation_id=#{obs1.id}")
    assert_selector("#occurrence_form")

    # Check Include for a recent observation
    checkboxes = all(
      "input[name='observation_ids[]'][type='checkbox']"
    )
    assert(checkboxes.any?, "Expected recent observation checkboxes")
    checkboxes.first.check

    click_button(:create_occurrence_submit.l)

    # After successful creation, should redirect away from form
    assert_no_selector("#occurrence_form", wait: 5)
  end
end

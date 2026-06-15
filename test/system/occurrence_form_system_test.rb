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

    # Check Include for a recent observation. The Phlex create form
    # namespaces the field as `occurrence[observation_ids][]` (via
    # `checkbox_field(:observation_ids)`).
    # `Views::Controllers::Occurrences::Projects::Form` emits hidden
    # fields with the same name so its Add All submission goes through
    # the same controller param path (#4284).
    checkboxes = all(
      "input[name='occurrence[observation_ids][]'][type='checkbox']"
    )
    assert_predicate(checkboxes, :any?,
                     "Expected recent observation checkboxes")
    checkboxes.first.check

    click_button(:create_occurrence_submit.l)

    # After successful creation, should redirect away from form
    assert_no_selector("#occurrence_form", wait: 5)
  end
end

# frozen_string_literal: true

require("test_helper")

# Smoke + HTML parity for
# `Views::Controllers::Observations::Show::MatchingObservationsPanel`.
class Views::Controllers::Observations::Show::MatchingObservationsPanelTest <
  ComponentTestCase
  def setup
    super
    @obs = observations(:detailed_unknown_obs)
  end

  def test_no_siblings_renders_create_occurrence_heading_link
    html = render(panel_with(siblings: [], occurrence: nil))

    assert_html(
      html,
      "a[href='#{routes.new_occurrence_path(observation_id: @obs.id)}']",
      text: :show_observation_add_matching_observations.l
    )
    assert_no_html(html, ".panel-body ul",
                   "Expected no sibling list when occurrence is nil")
  end

  def test_siblings_render_with_occurrence_link
    occurrence = occurrences(:occ_field_slip_one)
    loc = locations(:obs_default_location)
    Observation.create!(user: users(:rolf), when: Time.zone.now,
                        location: loc, where: loc.name,
                        name: names(:boletus_edulis),
                        occurrence: occurrence)
    siblings = occurrence.observations.reload.to_a

    html = render(panel_with(siblings: siblings, occurrence: occurrence))

    assert_html(html, "a[href='#{routes.occurrence_path(occurrence)}']")
    siblings.each do |sib|
      assert_html(
        html,
        "a[href='#{routes.permanent_observation_path(sib.id)}']"
      )
    end
  end

  private

  def panel_with(siblings:, occurrence:)
    Views::Controllers::Observations::Show::MatchingObservationsPanel.new(
      obs: @obs, occurrence: occurrence, siblings: siblings
    )
  end
end

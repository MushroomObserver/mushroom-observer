# frozen_string_literal: true

require("test_helper")

# Smoke + HTML parity for
# `Views::Controllers::Observations::Show::AssociatedObservationsPanel`.
class Views::Controllers::Observations::Show::AssociatedObservationsPanelTest <
  ComponentTestCase
  def setup
    super
    @user = users(:rolf)
    @obs = observations(:detailed_unknown_obs)
  end

  def test_no_siblings_renders_create_occurrence_heading_link
    html = render(panel_with(siblings: [], occurrence: nil))

    assert_html(
      html, "a[href='#{routes.new_occurrence_path(observation_id: @obs.id)}']"
    )
    assert_includes(html, :show_observation_add_matching_observations.l)
    # No body when no siblings.
    assert_no_html(html, ".panel-body ul")
  end

  def test_siblings_render_with_occurrence_link
    occurrence = Occurrence.joins(:observations).group("occurrences.id").
                 having("count(observations.id) > 1").first ||
                 skip("Need an occurrence with multiple observations")
    siblings = occurrence.observations.to_a

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
    Views::Controllers::Observations::Show::AssociatedObservationsPanel.new(
      obs: @obs, occurrence: occurrence, siblings: siblings, user: @user
    )
  end
end

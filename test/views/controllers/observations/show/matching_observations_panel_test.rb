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
    sibling = add_sibling_to(occurrence)
    siblings = [sibling]

    html = render(panel_with(siblings: siblings, occurrence: occurrence))

    assert_html(html, "a[href='#{routes.occurrence_path(occurrence)}']")
    siblings.each do |sib|
      assert_html(
        html,
        "a[href='#{routes.permanent_observation_path(sib.id)}']"
      )
    end
  end

  def test_current_observation_renders_first_as_plain_text
    occurrence = occurrences(:occ_field_slip_one)
    current = occurrence.primary_observation
    sibling = add_sibling_to(occurrence)

    html = render(panel_with(obs: current, siblings: [sibling],
                             occurrence: occurrence))

    assert_no_html(
      html, "a[href='#{routes.permanent_observation_path(current.id)}']",
      "Current observation should render as plain text, not a link"
    )
    assert_html(html,
                "a[href='#{routes.permanent_observation_path(sibling.id)}']")
  end

  def test_occurrence_primary_gets_star_icon
    occurrence = occurrences(:occ_field_slip_one)
    primary = occurrence.primary_observation
    sibling = add_sibling_to(occurrence)

    html = render(panel_with(obs: primary, siblings: [sibling],
                             occurrence: occurrence))

    assert_html(html, ".mo-icon-is-primary")
    assert_no_html(html, ".mo-icon-read-only")
  end

  def test_reflection_gets_read_only_icon
    occurrence = occurrences(:occ_field_slip_one)
    primary = occurrence.primary_observation
    sibling = add_sibling_to(occurrence)
    sibling.update_column(:reflected_at, Time.zone.now)

    html = render(panel_with(obs: primary, siblings: [sibling],
                             occurrence: occurrence))

    assert_html(html, ".mo-icon-read-only")
  end

  # The star icon isn't tied to "is the current observation" -- a
  # sibling that happens to be the occurrence's primary gets it too,
  # on its link row.
  def test_primary_as_sibling_gets_star_icon_on_link_row
    occurrence = occurrences(:occ_field_slip_one)
    primary = occurrence.primary_observation
    current = add_sibling_to(occurrence)

    html = render(panel_with(obs: current, siblings: [primary],
                             occurrence: occurrence))

    assert_html(html, ".mo-icon-is-primary")
    assert_html(html,
                "a[href='#{routes.permanent_observation_path(primary.id)}']")
  end

  # Both icons apply when the occurrence primary is also a read-only
  # reflection -- each icon needs a gap, or they render flush against
  # each other.
  def test_primary_and_reflection_icons_both_get_gap_class
    occurrence = occurrences(:occ_field_slip_one)
    primary = occurrence.primary_observation
    primary.update_column(:reflected_at, Time.zone.now)
    sibling = add_sibling_to(occurrence)

    html = render(panel_with(obs: primary, siblings: [sibling],
                             occurrence: occurrence))

    assert_html(html, ".mo-icon-is-primary")
    assert_html(html, ".mo-icon-read-only.icon-text-gap")
  end

  private

  def add_sibling_to(occurrence)
    loc = locations(:obs_default_location)
    Observation.create!(user: users(:rolf), when: Time.zone.now,
                        location: loc, where: loc.name,
                        name: names(:boletus_edulis),
                        occurrence: occurrence)
  end

  def panel_with(siblings:, occurrence:, obs: @obs)
    Views::Controllers::Observations::Show::MatchingObservationsPanel.new(
      obs: obs, occurrence: occurrence, siblings: siblings
    )
  end
end

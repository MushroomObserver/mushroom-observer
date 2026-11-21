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
    assert_html(html,
                "#current_observation_row .matching-observation-marker " \
                ".mo-icon-chevron-right")
  end

  # The panel is the key a reader uses to decode a number on a
  # comment or photo, so a numbered sibling shows the same one,
  # and the current observation shows none (#5718).
  def test_markers_label_siblings_only
    occurrence = occurrences(:occ_field_slip_one)
    current = occurrence.primary_observation
    sibling = add_sibling_to(occurrence)

    html = render(panel_with(obs: current, siblings: [sibling],
                             occurrence: occurrence,
                             markers: { sibling.id => 1 }))

    path = routes.permanent_observation_path(sibling.id)
    assert_html(html, "a[href='#{path}'] .sibling-marker", text: "1")
    assert_no_html(html, "#current_observation_row .sibling-marker",
                   "The observation being shown carries no number")
    assert_html(html, "#current_observation_row .mo-icon-chevron-right")
  end

  def test_no_markers_renders_no_numbers
    occurrence = occurrences(:occ_field_slip_one)
    sibling = add_sibling_to(occurrence)

    html = render(panel_with(siblings: [sibling],
                             occurrence: occurrence))

    assert_no_html(html, ".sibling-marker",
                   "No numbers without a marker map")
    # The marker column still renders regardless -- the current
    # observation's row always gets its chevron.
    assert_html(html, "#current_observation_row .mo-icon-chevron-right")
  end

  def test_every_row_has_an_id_badge
    occurrence = occurrences(:occ_field_slip_one)
    current = occurrence.primary_observation
    sibling = add_sibling_to(occurrence)

    html = render(panel_with(obs: current, siblings: [sibling],
                             occurrence: occurrence))

    assert_html(html, ".badge-id", text: current.id.to_s)
    assert_html(html, ".badge-id", text: sibling.id.to_s)
  end

  # Each row is a 3-column flex layout: marker, name, then id badge,
  # in that column order -- so a long name wraps inside the name
  # column instead of pushing the badge off the row (#5718 follow-up).
  def test_row_columns_are_marker_then_name_then_id_badge
    occurrence = occurrences(:occ_field_slip_one)
    sibling = add_sibling_to(occurrence)

    html = render(panel_with(siblings: [sibling], occurrence: occurrence,
                             markers: { sibling.id => 1 }))

    assert_html(
      html,
      ".matching-observation-marker ~ .matching-observation-name " \
      "~ .badge-id"
    )
  end

  # The current observation isn't a link, so its badge shouldn't be
  # either -- only siblings get the interactive copy-to-clipboard
  # button form.
  def test_only_sibling_badges_are_interactive
    occurrence = occurrences(:occ_field_slip_one)
    current = occurrence.primary_observation
    sibling = add_sibling_to(occurrence)

    html = render(panel_with(obs: current, siblings: [sibling],
                             occurrence: occurrence))

    assert_html(html, ".badge-id", text: current.id.to_s)
    assert_html(html, "button.badge-id", text: sibling.id.to_s)
  end

  def test_occurrence_primary_gets_star_icon
    occurrence = occurrences(:occ_field_slip_one)
    primary = occurrence.primary_observation
    sibling = add_sibling_to(occurrence)

    html = render(panel_with(obs: primary, siblings: [sibling],
                             occurrence: occurrence))

    assert_html(html, ".mo-icon-is-primary")
    assert_no_html(html, ".mo-icon-reflection")
  end

  def test_reflection_gets_read_only_icon
    occurrence = occurrences(:occ_field_slip_one)
    primary = occurrence.primary_observation
    sibling = add_sibling_to(occurrence)
    sibling.update_column(:reflected_at, Time.zone.now)

    html = render(panel_with(obs: primary, siblings: [sibling],
                             occurrence: occurrence))

    assert_html(html, ".mo-icon-reflection")
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
  # reflection. The first icon is the name column's first child (no
  # gap needed there); the second follows the first icon and needs
  # a gap.
  def test_primary_and_reflection_icons_both_render_with_second_gapped
    occurrence = occurrences(:occ_field_slip_one)
    primary = occurrence.primary_observation
    primary.update_column(:reflected_at, Time.zone.now)
    sibling = add_sibling_to(occurrence)

    html = render(panel_with(obs: primary, siblings: [sibling],
                             occurrence: occurrence))

    assert_html(html, ".mo-icon-is-primary")
    assert_no_html(html, ".icon-text-gap > .mo-icon-is-primary")
    assert_html(html, ".icon-text-gap > .mo-icon-reflection")
  end

  private

  def add_sibling_to(occurrence)
    loc = locations(:obs_default_location)
    Observation.create!(user: users(:rolf), when: Time.zone.now,
                        location: loc, where: loc.name,
                        name: names(:boletus_edulis),
                        occurrence: occurrence)
  end

  def panel_with(siblings:, occurrence:, obs: @obs, markers: {})
    Views::Controllers::Observations::Show::MatchingObservationsPanel.new(
      obs: obs, occurrence: occurrence, siblings: siblings,
      markers: markers
    )
  end
end

# frozen_string_literal: true

require("test_helper")

class Views::Controllers::Observations::Show::ObservationDetailsPanelTest <
  ComponentTestCase
  def setup
    super
    @user = users(:rolf)
    @obs = observations(:detailed_unknown_obs)
  end

  def test_renders_panel_id
    html = render(panel_with(@obs))

    assert_html(html, "#observation_details")
  end

  # Sibling records: when a sibling carries a Sequence with a
  # deposit URL, the panel renders the sibling sequence row +
  # the `[archive]` link from `SiblingRecords`. Covers the
  # `render_sequences` sibling-block path + the
  # `render_sibling_sequence_archive` body.
  def test_sibling_sequence_with_archive_renders
    seq = sequences(:deposited_sequence)
    sibling = seq.observation

    html = render(
      Views::Controllers::Observations::Show::ObservationDetailsPanel.new(
        obs: @obs, user: @user, sites: [], siblings: [sibling]
      )
    )

    # Sibling sequence's show link
    assert_html(html, "a[href='#{routes.sequence_path(seq.id)}']")
    # `[archive]` inline link from `render_sibling_sequence_archive`
    assert_html(
      html, "a[href='#{seq.accession_url}'][target='_blank']",
      text: :show_observation_archive_link.t
    )
  end

  # Sibling herbarium record covers
  # `render_sibling_herbarium_record` and
  # `render_mcp_search_link` when the herbarium is
  # `web_searchable?`.
  def test_sibling_herbarium_record_with_web_searchable
    record = ::HerbariumRecord.joins(:herbarium).
             where(herbaria: { code: %w[NY NEB FH MICH] }).first ||
             ::HerbariumRecord.joins(:observations).distinct.first ||
             skip("Need a herbarium_record attached to an obs")
    sibling = record.observations.first || skip("Sibling missing")

    html = render(
      Views::Controllers::Observations::Show::ObservationDetailsPanel.new(
        obs: @obs, user: @user, sites: [], siblings: [sibling]
      )
    )

    # Sibling herb-record show link
    assert_html(
      html, "a[href='#{routes.herbarium_record_path(record.id)}']"
    )
    # MO attribution link
    assert_html(
      html, "small.text-muted " \
            "a[href='#{routes.permanent_observation_path(sibling.id)}']"
    )
  end

  private

  def panel_with(obs, user = @user)
    Views::Controllers::Observations::Show::ObservationDetailsPanel.new(
      obs: obs, user: user, sites: [], siblings: []
    )
  end
end

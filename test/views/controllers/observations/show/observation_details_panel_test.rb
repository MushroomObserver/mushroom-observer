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

  # --- Collector / Entered by (#4211) ---

  def test_who_collector_is_creator_no_entered_by
    @obs.collector = @obs.user.unique_text_name
    @obs.collector_user_id = @obs.user_id

    html = render(panel_with(@obs))
    text = who_text(html)

    assert_includes(text, :COLLECTOR.l)
    assert_html(html,
                "#observation_who a[href='#{routes.user_path(@obs.user_id)}']")
    assert_not_includes(text, :ENTERED_BY.l)
  end

  def test_who_free_text_collector_shows_entered_by
    @obs.collector = "Jane Forager"
    @obs.collector_user_id = nil

    text = who_text(render(panel_with(@obs)))

    assert_includes(text, "Jane Forager")
    assert_includes(text, :ENTERED_BY.l)
  end

  def test_who_collector_user_links_and_entered_by
    # A collector who is not the obs owner (detailed_unknown_obs is mary's)
    collector = users(:katrina)
    @obs.collector_user = collector
    @obs.collector = collector.unique_text_name

    html = render(panel_with(@obs))

    assert_html(
      html, "#observation_who a[href='#{routes.user_path(collector.id)}']"
    )
    assert_includes(who_text(html), :ENTERED_BY.l)
  end

  def test_who_plain_text_when_logged_out
    @obs.collector = @obs.user.unique_text_name
    @obs.collector_user_id = @obs.user_id

    text = who_text(render(panel_with(@obs, nil)))

    assert_includes(text, @obs.user.unique_text_name)
  end

  def test_who_collector_unrecorded_suppresses_collector_line
    obs = observations(:minimal_unknown_obs)
    assert(obs.field_slip_id.present?, "fixture should have a field slip")
    obs.collector = nil
    obs.collector_user_id = nil

    text = who_text(render(panel_with(obs)))

    assert_not_includes(text, :COLLECTOR.l)
    assert_includes(text, :ENTERED_BY.l)
    assert_includes(text, obs.user.unique_text_name)
  end

  def test_who_send_question_link_when_allowed
    obs = observations(:owner_accepts_general_questions)
    viewer = users(:rolf)
    assert_not_equal(obs.user, viewer)

    html = render(panel_with(obs, viewer))

    # The "[" ... "]" send-question modal link rides the who line.
    assert_html(html, "#observation_who a[data-controller='modal-toggle']")
  end

  def test_notes_render_without_collector_special_casing
    @obs.notes = { Substrate: "wood", Other: "field notes here" }

    html = render(panel_with(@obs))
    notes = Nokogiri::HTML.fragment(html).at_css("#observation_notes").text

    assert_includes(notes, "field notes here")
    assert_includes(notes, "wood")
  end

  private

  def who_text(html)
    Nokogiri::HTML.fragment(html).at_css("#observation_who").text
  end

  def panel_with(obs, user = @user)
    Views::Controllers::Observations::Show::ObservationDetailsPanel.new(
      obs: obs, user: user, sites: [], siblings: []
    )
  end
end

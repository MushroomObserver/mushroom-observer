# frozen_string_literal: true

require("test_helper")

# test the helpers for ObservationsController
class ObservationsHelperTest < ActionView::TestCase
  include ObjectLinkHelper

  def test_show_observation_name
    user = users(:rolf)
    location = locations(:albion)

    # approved name
    current_name = names(:lactarius_alpinus)
    Observation.new(
      name: current_name, user:, when: Time.current, where: location
    )
    assert_match(
      link_to(current_name.display_name_brief_authors.t.small_author,
              name_path(id: current_name.id),
              class: "obs_consensus_naming_link_#{current_name.id}"),
      obs_title_consensus_name_link(name: current_name, user:),
      "Observation of a current Name should link to that Name"
    )

    # deprecated name
    deprecated_name = names(:lactarius_alpigenes)
    Observation.new(
      name: deprecated_name, user: user, when: Time.current, where: location
    )
    assert_match(
      link_to_display_name_brief_authors(
        user, deprecated_name,
        class: "obs_consensus_deprecated_synonym_link_#{deprecated_name.id}"
      ),
      obs_title_consensus_name_link(name: deprecated_name, user:).unescape_html,
      "Observation of deprecated Name should link to it"
    )
    assert_match(
      link_to_display_name_without_authors(
        user, current_name,
        class: "obs_preferred_synonym_link_#{current_name.id}"
      ),
      obs_title_consensus_name_link(name: deprecated_name, user:).unescape_html,
      "Observation of deprecated Name should link to preferred Name"
    )
  end

  # --- Collector / Entered by (#4211) ---

  def who_text(html)
    Nokogiri::HTML.fragment(html).at_css("p#observation_who").text
  end

  def test_who_collector_is_creator_no_entered_by
    obs = observations(:minimal_unknown_obs)
    obs.collector = obs.user.unique_text_name
    obs.collector_user_id = obs.user_id

    text = who_text(observation_details_who(obs: obs, user: nil))

    assert_includes(text, :COLLECTOR.l)
    assert_includes(text, obs.user.unique_text_name)
    assert_not_includes(text, :ENTERED_BY.l)
  end

  def test_who_free_text_collector_shows_entered_by
    obs = observations(:minimal_unknown_obs)
    obs.collector = "Jane Forager"
    obs.collector_user_id = nil

    text = who_text(observation_details_who(obs: obs, user: nil))

    assert_includes(text, "Jane Forager")
    assert_includes(text, :ENTERED_BY.l)
    assert_includes(text, obs.user.unique_text_name)
  end

  def test_who_collector_user_renders_link_and_entered_by
    obs = observations(:minimal_unknown_obs)
    collector = users(:rolf)
    obs.collector_user = collector
    obs.collector = collector.unique_text_name

    # View as the obs owner so the "ask a question" email link (which
    # pulls in unrelated modal helpers) is skipped; links still render.
    html = observation_details_who(obs: obs, user: obs.user)
    doc = Nokogiri::HTML.fragment(html)

    assert_includes(who_text(html), :ENTERED_BY.l)
    assert(doc.at_css("a[href='#{user_path(id: collector.id)}']"),
           "Collector should link to the collector_user")
    assert(doc.at_css("a[href='#{user_path(id: obs.user_id)}']"),
           "Entered by should link to the entering user")
  end

  def test_notes_suppresses_collector_key
    obs = observations(:minimal_unknown_obs)
    obs.collector = obs.user.unique_text_name # column populated -> suppress
    obs.notes = { Collector: "_user mary_", Substrate: "wood",
                  Other: "field notes here" }

    text = Nokogiri::HTML.fragment(observation_details_notes(obs: obs)).
           at_css("#observation_notes").text

    assert_includes(text, "field notes here")
    assert_includes(text, "wood")
    assert_not_includes(text, "Collector")
  end

  def test_notes_keeps_collector_key_for_legacy_rows
    obs = observations(:minimal_unknown_obs)
    obs.collector = nil # no column value -> legacy row, keep notes key
    obs.notes = { Collector: "Jane Forager", Other: "field notes here" }

    text = Nokogiri::HTML.fragment(observation_details_notes(obs: obs)).
           at_css("#observation_notes").text

    assert_includes(text, "Jane Forager")
    assert_includes(text, "Collector")
  end
end

# frozen_string_literal: true

require("test_helper")

# Covers the obs-title builder chain — `ConsensusNameLink`
# composing `DisplayNameBriefAuthorsLink` and
# `DisplayNameWithoutAuthorsLink`.
class Observations::ConsensusNameLinkTest < ActionView::TestCase
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
      ::Observations::ConsensusNameLink.for(name: current_name, user:),
      "Observation of a current Name should link to that Name"
    )

    # deprecated name
    deprecated_name = names(:lactarius_alpigenes)
    Observation.new(
      name: deprecated_name, user: user, when: Time.current, where: location
    )
    title = ::Observations::ConsensusNameLink.for(
      name: deprecated_name, user: user
    )
    assert_match(
      ::Observations::DisplayNameBriefAuthorsLink.for(
        user: user, name: deprecated_name,
        class: "obs_consensus_deprecated_synonym_link_#{deprecated_name.id}"
      ),
      title.unescape_html,
      "Observation of deprecated Name should link to it"
    )
    assert_match(
      ::Observations::DisplayNameWithoutAuthorsLink.for(
        user: user, name: current_name,
        class: "obs_preferred_synonym_link_#{current_name.id}"
      ),
      title.unescape_html,
      "Observation of deprecated Name should link to preferred Name"
    )
  end
end

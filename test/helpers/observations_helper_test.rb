# frozen_string_literal: true

require("test_helper")

# test the helpers for ObservationsController
class ObservationsHelperTest < ActionView::TestCase
  def test_show_observation_name
    user = users(:rolf)
    location = locations(:albion)

    # approved name
    current_name = names(:lactarius_alpinus)
    Observation.new(
      name: current_name, user: user, when: Time.current, where: location
    )
    assert_match(
      link_to(current_name.display_name_brief_authors.t,
              name_path(id: current_name.id)),
      obs_title_consensus_name_link(name: current_name),
      "Observation of a current Name should link to that Name"
    )

    # deprecated name
    deprecated_name = names(:lactarius_alpigenes)
    Observation.new(
      name: deprecated_name, user: user, when: Time.current, where: location
    )
    assert_match(
      link_to_display_name_brief_authors(deprecated_name),
      obs_title_consensus_name_link(name: deprecated_name).unescape_html,
      "Observation of deprecated Name should link to it"
    )
    assert_match(
      link_to_display_name_without_authors(current_name),
      obs_title_consensus_name_link(name: deprecated_name).unescape_html,
      "Observation of deprecated Name should link to approved Name"
    )
  end
end

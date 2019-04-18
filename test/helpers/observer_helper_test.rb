# frozen_string_literal: true
require "test_helper"

# test the helpers for ObserverController
class ObserverHelperTest < ActionView::TestCase
  def test_show_observation_name
    user = users(:rolf)
    location = locations(:albion)

    # approved name
    current_name = names(:lactarius_alpinus)
    Observation.new(
      name: current_name, user: user, when: Time.current, where: location
    )
    assert_match(
      link_to(current_name.short_authors_display_name.t,
              controller: :name,
              action: :show_name, id: current_name.id),
      obs_title_consensus_id(current_name),
      "Observation of a current Name should link to that Name"
    )

    # deprecated name
    deprecated_name = names(:lactarius_alpigenes)
    Observation.new(
      name: deprecated_name, user: user, when: Time.current, where: location
    )
    assert_match(
      "#{link_to_short_authors_display_name(deprecated_name)} (Site ID) " \
      "(#{link_to_display_name_without_authors(current_name)})",
      obs_title_consensus_id(deprecated_name),
      "Observation of deprecated Name should link to it and approved Name"
    )
  end
end

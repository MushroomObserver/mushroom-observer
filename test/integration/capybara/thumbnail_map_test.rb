# frozen_string_literal: true

require("test_helper")

class ThumbnailMapTest < CapybaraIntegrationTestCase
  # -------------------------------------------------------------------------
  #  Need integration test to make sure session and actions are all working
  #  together correctly.
  # -------------------------------------------------------------------------

  def test_thumbnail_maps
    visit("/#{observations(:minimal_unknown_obs).id}")
    assert_selector("body.observations__show")

    login("dick")
    assert_selector("body.observations__show")
    assert_selector("div.thumbnail-map")
    click_link(text: "Hide thumbnail map")
    assert_selector("body.observations__show")
    assert_no_selector("div.thumbnail-map")

    visit("/#{observations(:detailed_unknown_obs).id}")
    assert_selector("body.observations__show")
    assert_no_selector("div.thumbnail-map")
  end
end
